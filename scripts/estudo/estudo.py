#!/usr/bin/env python3
"""Mosaic OS study mode ("modo Estudo"): during the study hours, the apps and
sites on the block list are closed. Everything else keeps working.

  estudo.py daemon      the service (systemd user unit mosaic-estudo.service)
  estudo.py estado      what is going on right now
  estudo.py agora MIN   start a session now, MIN minutes long (the menu's button)
  estudo.py liberar --motivo "..." (--tudo | --app ID... | --site DOMAIN...) [--min N]
                        let something through for a while. There is no button
                        for it on purpose: it is asked for, with a reason
  estudo.py trancar     end a release early
  estudo.py historico   the releases made so far, with their reasons

Files
  ~/.config/mosaic-os/estudo/agenda.json   the schedule and the lists (the menu writes it)
  ~/.local/state/mosaic-os/estudo/
    vigente.json    the schedule as it was when the day began
    sessao.json     a session started by hand ("agora")
    liberado.json   a release in force
    estado.json     what the shell shows (the menu, the pill on the top band)
    historico.log   every release and its reason

Rules
  - What counts today is the day's snapshot (vigente) together with the file as
    it is now: a change that makes things stricter (a longer block, one more
    app) is in force at once; one that makes them looser (a shorter block, an
    app taken out) only when the next day's snapshot is taken.
  - Apps are matched by window class (Hyprland) and, for the ones that live in
    the tray, by process name. The window's process gets SIGTERM, and SIGKILL
    if it is still there on the next pass.
  - Sites go into /etc/hosts through a small root helper (instalar-sites.sh),
    only while a session is on.
  - Outside a session the daemon sleeps: one look at three small files a minute.
"""
import argparse
import json
import os
import re
import select
import signal
import socket
import subprocess
import sys
import time
from datetime import datetime, timedelta

HOME = os.path.expanduser("~")
CONF = os.path.join(HOME, ".config/mosaic-os/estudo/agenda.json")
STATE = os.path.join(HOME, ".local/state/mosaic-os/estudo")
VIGENTE = os.path.join(STATE, "vigente.json")
SESSAO = os.path.join(STATE, "sessao.json")
LIBERADO = os.path.join(STATE, "liberado.json")
ESTADO = os.path.join(STATE, "estado.json")
HISTORICO = os.path.join(STATE, "historico.log")
PIDFILE = os.path.join(STATE, "daemon.pid")
HELPER = "/usr/local/libexec/mosaic-estudo-hosts"
HOSTS_BEGIN = "# >>> mosaic-estudo"
HOSTS_END = "# <<< mosaic-estudo"

SWEEP_S = 20      # during a session: how often windows and processes are checked
IDLE_S = 60       # outside one: how often the files are looked at
WARN_S = 300      # the notice before a session starts
MAX_MIN = 16 * 60 # the longest block of a day

# never closed, whatever the lists say: the two apps the mode is for, and the desktop itself
PROTECTED = re.compile(r"(com\.anthropic\.claude|claude|firefox.*|zen.*|org\.mozilla\.firefox|quickshell|org\.quickshell|hyprland)", re.I)
DOMAIN = re.compile(r"[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+")
# /etc/hosts has no wildcards: the usual sub-domains go in by name
SUBS = ("www.", "m.")
EXTRA = {
    "youtube.com": ["music.youtube.com", "youtu.be", "www.youtube-nocookie.com"],
    "reddit.com": ["old.reddit.com", "new.reddit.com"],
    "twitter.com": ["mobile.twitter.com"],
    "x.com": ["mobile.x.com"],
    "twitch.tv": ["player.twitch.tv"],
    "whatsapp.com": ["web.whatsapp.com"],
    "telegram.org": ["web.telegram.org"],
    "discord.com": ["canary.discord.com", "ptb.discord.com"],
}

DEFAULT_APPS = [
    {"id": "steam", "nome": "Steam", "classes": ["steam", r"steam_app_\d+", "steam_proton", "steamwebhelper"], "procs": ["steam", "steamwebhelper"]},
    {"id": "hydra", "nome": "Hydra", "classes": ["hydra", "hydralauncher"], "procs": ["hydralauncher"]},
    {"id": "lutris", "nome": "Lutris", "classes": [r"net\.lutris\.lutris", "lutris"], "procs": ["lutris"]},
    {"id": "epic", "nome": "Epic Games e Heroic", "classes": [r"epicgameslauncher.*", "heroic"], "procs": ["heroic"]},
    {"id": "minecraft", "nome": "Minecraft", "classes": [r"minecraft.*", r"org\.prismlauncher\.prismlauncher", "prismlauncher"], "procs": ["minecraft-launcher", "prismlauncher"]},
    {"id": "wine", "nome": "Jogos de Windows (Wine/Proton)", "classes": [r".*\.exe", "wine"], "procs": ["wineserver"]},
    {"id": "gamescope", "nome": "Modo console (gamescope)", "classes": ["gamescope"], "procs": ["gamescope", "gamescope-wl"]},
    {"id": "sudoku", "nome": "Sudoku", "classes": [r"org\.gnome\.sudoku", "sudoku-solver", r"io\.gitlab\.cyberphantom52\.sudoku_solver"], "procs": []},
    {"id": "zapzap", "nome": "ZapZap", "classes": [r"com\.rtosta\.zapzap", "zapzap"], "procs": []},
    {"id": "whatsie", "nome": "WhatSie", "classes": [r"com\.ktechpit\.whatsie", "whatsie"], "procs": ["whatsie"]},
    {"id": "discord", "nome": "Discord", "classes": ["discord", "vesktop", "webcord", "legcord"], "procs": ["Discord", "vesktop"]},
    {"id": "telegram", "nome": "Telegram", "classes": [r"org\.telegram\.desktop", r"telegram.*"], "procs": ["telegram-desktop", "Telegram"]},
    {"id": "kdeconnect-sms", "nome": "KDE Connect SMS", "classes": [r"org\.kde\.kdeconnect\.sms"], "procs": []},
]
DEFAULT_SITES = [
    "youtube.com", "instagram.com", "facebook.com", "twitter.com", "x.com", "tiktok.com", "reddit.com",
    "twitch.tv", "kick.com", "netflix.com", "primevideo.com", "disneyplus.com", "discord.com",
    "web.whatsapp.com", "web.telegram.org", "pinterest.com", "9gag.com",
]


def default_agenda():
    return {
        "dias": [{"ativo": False, "inicio": "14:00", "minutos": 120} for _ in range(7)],  # 0 = Monday
        "apps": DEFAULT_APPS,
        "sites": DEFAULT_SITES,
    }


def empty_agenda():
    return {"dias": [{"ativo": False, "inicio": "14:00", "minutos": 120} for _ in range(7)], "apps": [], "sites": []}


# ---------- files ----------

def load(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def clean_domain(d):
    d = str(d).strip().lower()
    d = re.sub(r"^[a-z]+://", "", d).split("/")[0]
    return d if DOMAIN.fullmatch(d) and len(d) < 254 else ""


def normalize(a):
    """Whatever is in the file, as a well-formed agenda (it is edited by hand too)."""
    out = empty_agenda()
    if not isinstance(a, dict):
        return out
    dias = a.get("dias")
    if isinstance(dias, list):
        for i, d in enumerate(dias[:7]):
            if not isinstance(d, dict):
                continue
            m = re.fullmatch(r"(\d{1,2}):(\d{2})", str(d.get("inicio", "")))
            if m and int(m[1]) < 24 and int(m[2]) < 60:
                out["dias"][i]["inicio"] = f"{int(m[1]):02d}:{m[2]}"
            try:
                out["dias"][i]["minutos"] = max(0, min(MAX_MIN, int(d.get("minutos", 0))))
            except (TypeError, ValueError):
                pass
            out["dias"][i]["ativo"] = bool(d.get("ativo")) and out["dias"][i]["minutos"] > 0
    for app in a.get("apps") or []:
        if not isinstance(app, dict) or not app.get("id"):
            continue
        classes = []
        for c in app.get("classes") or []:
            try:
                re.compile(str(c))
                classes.append(str(c))
            except re.error:
                pass
        procs = [str(p) for p in app.get("procs") or [] if re.fullmatch(r"[\w.+-]{2,64}", str(p))]
        if classes or procs:
            out["apps"].append({"id": str(app["id"]), "nome": str(app.get("nome") or app["id"]), "classes": classes, "procs": procs})
    seen = set()
    for s in a.get("sites") or []:
        d = clean_domain(s)
        if d and d not in seen:
            seen.add(d)
            out["sites"].append(d)
    return out


# ---------- the schedule ----------

def block_end(agenda, now):
    """If `now` is inside one of the agenda's blocks: when it ends. A block that
    started yesterday may run past midnight."""
    end = None
    for back in (0, 1):
        day = (now - timedelta(days=back)).date()
        d = agenda["dias"][day.weekday()]
        if not d["ativo"]:
            continue
        h, m = d["inicio"].split(":")
        start = datetime(day.year, day.month, day.day, int(h), int(m))
        stop = start + timedelta(minutes=d["minutos"])
        if start <= now < stop and (end is None or stop > end):
            end = stop
    return end


def next_start(agenda, now):
    best = None
    for ahead in range(8):
        day = (now + timedelta(days=ahead)).date()
        d = agenda["dias"][day.weekday()]
        if not d["ativo"]:
            continue
        h, m = d["inicio"].split(":")
        start = datetime(day.year, day.month, day.day, int(h), int(m))
        if start > now and (best is None or start < best):
            best = start
    return best


def merged_apps(*lists):
    """The union of the block lists, by id (the patterns of both)."""
    by = {}
    for apps in lists:
        for a in apps:
            cur = by.setdefault(a["id"], {"id": a["id"], "nome": a["nome"], "classes": [], "procs": []})
            cur["classes"] += [c for c in a["classes"] if c not in cur["classes"]]
            cur["procs"] += [p for p in a["procs"] if p not in cur["procs"]]
    return list(by.values())


def expand_sites(sites):
    out = set()
    for d in sites:
        out.add(d)
        if not d.startswith(("www.", "m.", "web.")):
            out.update(s + d for s in SUBS)
        out.update(EXTRA.get(d, []))
    return out


class Mode:
    """Everything that decides whether the mode is on right now."""

    def __init__(self, now):
        self.now = now
        raw = load(CONF)
        if raw is None:
            raw = default_agenda()
            save(CONF, raw)
        self.agenda = normalize(raw)
        vig = load(VIGENTE)
        if not isinstance(vig, dict) or "agenda" not in vig:
            vig = {"dia": now.date().isoformat(), "agenda": self.agenda}
            save(VIGENTE, vig)
        self.vigente = normalize(vig["agenda"])
        # the day turned: today's snapshot is the file as it is now (never in the
        # middle of a session that came from yesterday)
        if vig.get("dia") != now.date().isoformat() and block_end(self.vigente, now) is None:
            vig = {"dia": now.date().isoformat(), "agenda": self.agenda}
            save(VIGENTE, vig)
            self.vigente = self.agenda
        self.pending = self.looser()

        ends = [e for e in (block_end(self.vigente, now), block_end(self.agenda, now)) if e]
        ses = load(SESSAO)
        if isinstance(ses, dict) and ses.get("ate", 0) > now.timestamp():
            ends.append(datetime.fromtimestamp(ses["ate"]))
        self.end = max(ends) if ends else None
        self.active = self.end is not None
        # the snapshot only speaks for today: tomorrow's is taken from the file
        today = next_start(self.vigente, now)
        if today and today.date() != now.date():
            today = None
        starts = [s for s in (today, next_start(self.agenda, now)) if s]
        self.next = min(starts) if starts else None

        self.apps = merged_apps(self.vigente["apps"], self.agenda["apps"])
        self.sites = list(dict.fromkeys(self.vigente["sites"] + self.agenda["sites"]))

        rel = load(LIBERADO)
        self.release = rel if isinstance(rel, dict) and rel.get("ate", 0) > now.timestamp() else None
        if self.release:
            if self.release.get("tudo"):
                self.apps, self.sites = [], []
            else:
                free = set(self.release.get("apps") or [])
                self.apps = [a for a in self.apps if a["id"] not in free]
                free_sites = set(self.release.get("sites") or [])
                self.sites = [s for s in self.sites if s not in free_sites]
        # blocking only while a session is on
        self.blocking = self.active and not (self.release and self.release.get("tudo"))

    def looser(self):
        """Whether the file is looser than today's snapshot somewhere: an app or
        a site taken out, or today's block turned off, moved or shortened. That
        part still holds today and only goes away tomorrow."""
        if {a["id"] for a in self.vigente["apps"]} - {a["id"] for a in self.agenda["apps"]}:
            return True
        if set(self.vigente["sites"]) - set(self.agenda["sites"]):
            return True
        old, new = (a["dias"][self.now.weekday()] for a in (self.vigente, self.agenda))
        if not old["ativo"]:
            return False
        if not new["ativo"]:
            return True

        def span(d):
            h, m = d["inicio"].split(":")
            return int(h) * 60 + int(m), int(h) * 60 + int(m) + d["minutos"]
        (a0, a1), (b0, b1) = span(old), span(new)
        return b0 > a0 or b1 < a1

    def state(self):
        return {
            "ativo": self.active,
            "ate": int(self.end.timestamp()) if self.end else 0,
            "proximo": int(self.next.timestamp()) if self.next else 0,
            "liberado": self.release,
            "pendente": self.pending,
            "sitesInstalado": os.access(HELPER, os.X_OK),
        }


# ---------- Hyprland ----------

def hypr_dir():
    base = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "hypr")
    try:
        dirs = sorted((os.path.join(base, d) for d in os.listdir(base)), key=os.path.getmtime, reverse=True)
    except OSError:
        return None
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        dirs.insert(0, os.path.join(base, sig))
    for d in dirs:
        if os.path.exists(os.path.join(d, ".socket2.sock")):
            return d
    return None


def hypr_clients():
    d = hypr_dir()
    if not d:
        return []
    try:
        with socket.socket(socket.AF_UNIX) as s:
            s.settimeout(2)
            s.connect(os.path.join(d, ".socket.sock"))
            s.sendall(b"j/clients")
            data = b""
            while chunk := s.recv(65536):
                data += chunk
        return json.loads(data)
    except (OSError, ValueError):
        return []


def hypr_events():
    d = hypr_dir()
    if not d:
        return None
    try:
        s = socket.socket(socket.AF_UNIX)
        s.connect(os.path.join(d, ".socket2.sock"))
        s.setblocking(False)
        return s
    except OSError:
        return None


# ---------- closing things ----------

class Closer:
    def __init__(self):
        self.asked = {}     # pid -> when it got SIGTERM
        self.told = {}      # app id -> when the last notice went out
        self.me = {os.getpid(), os.getppid(), 1}

    def stop(self, pid, app, end):
        if pid in self.me or pid <= 1:
            return
        now = time.time()
        first = pid not in self.asked or now - self.asked[pid] > 120
        try:
            # still there since the last pass: no more asking nicely
            os.kill(pid, signal.SIGTERM if first or now - self.asked[pid] < 4 else signal.SIGKILL)
        except OSError:
            return
        if first:
            self.asked[pid] = now
        if now - self.told.get(app["id"], 0) > 30:
            self.told[app["id"]] = now
            notify(f"{app['nome']} está bloqueado", f"Modo Estudo até as {end:%H:%M}.", "critical")

    def sweep(self, mode):
        if not mode.apps:
            return
        rules = [(a, [re.compile(c, re.I) for c in a["classes"]], {p[:15] for p in a["procs"]}, set(a["procs"])) for a in mode.apps]
        for w in hypr_clients():
            names = [w.get("class") or "", w.get("initialClass") or ""]
            if any(PROTECTED.fullmatch(n) for n in names if n):
                continue
            for app, classes, _, _ in rules:
                if any(c.fullmatch(n) for c in classes for n in names if n):
                    self.stop(int(w.get("pid", 0)), app, mode.end)
                    break
        uid = os.getuid()
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            base = "/proc/" + entry
            try:
                if os.stat(base).st_uid != uid:
                    continue
                with open(base + "/comm") as f:
                    comm = f.read().strip()
                try:
                    exe = os.path.basename(os.readlink(base + "/exe"))
                except OSError:
                    exe = ""
            except OSError:
                continue
            for app, _, comms, exes in rules:
                if comm in comms or exe in exes:
                    self.stop(int(entry), app, mode.end)
                    break
        # forget the ones that are gone
        self.asked = {p: t for p, t in self.asked.items() if os.path.exists(f"/proc/{p}")}


def notify(title, body, urgency="normal"):
    try:
        subprocess.Popen(["notify-send", "-a", "Modo Estudo", "-i", "accessories-dictionary", "-u", urgency, "-t", "6000", title, body],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


# ---------- sites ----------

def hosts_now():
    """The domains our block of /etc/hosts holds, or None when there is no block."""
    try:
        with open("/etc/hosts") as f:
            lines = f.read().split("\n")
    except OSError:
        return None
    if HOSTS_BEGIN not in lines:
        return None
    out = set()
    for line in lines[lines.index(HOSTS_BEGIN) + 1:]:
        if line == HOSTS_END:
            break
        parts = line.split()
        if len(parts) == 2:
            out.add(parts[1])
    return out


def hosts_set(sites):
    """Make /etc/hosts block exactly these sites (none: take our block out)."""
    if not os.access(HELPER, os.X_OK):
        return
    want = expand_sites(sites)
    have = hosts_now()
    if (have or set()) == want and (have is None) == (not want):
        return
    try:
        if want:
            subprocess.run(["sudo", "-n", HELPER, "on"], input="\n".join(sorted(want)) + "\n", text=True, timeout=15,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(["sudo", "-n", HELPER, "off"], timeout=15, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        pass


# ---------- the daemon ----------

def daemon():
    os.makedirs(STATE, exist_ok=True)
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    # a signal (the menu saved, "agora", "liberar") wakes the loop up at once
    rd, wr = socket.socketpair()
    rd.setblocking(False)
    wr.setblocking(False)
    signal.set_wakeup_fd(wr.fileno())
    signal.signal(signal.SIGUSR1, lambda *_: None)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    closer = Closer()
    events = None
    buf = b""
    was_blocking = False
    last_state = None
    last_sweep = 0.0
    warned = 0

    while True:
        now = datetime.now()
        mode = Mode(now)
        st = mode.state()
        if st != last_state:
            save(ESTADO, st)
            last_state = st

        if mode.blocking:
            if not was_blocking:
                notify("Modo Estudo ligado", f"Até as {mode.end:%H:%M}. Jogos, mensagens e sites da lista ficam fechados.")
            hosts_set(mode.sites)
            if events is None:
                events = hypr_events()
            if time.time() - last_sweep >= SWEEP_S - 1:
                closer.sweep(mode)
                last_sweep = time.time()
            wait = min(SWEEP_S, max(1, (mode.end - now).total_seconds()))
        else:
            if was_blocking:
                notify("Modo Estudo desligado", "Liberado por pedido." if mode.active else "Acabou por hoje. Bom descanso!")
            hosts_set([])
            if events is not None:
                events.close()
                events = None
                buf = b""
            last_sweep = 0.0
            wait = IDLE_S
            if mode.active and mode.release:  # a full release: back when it ends
                wait = min(wait, max(1, mode.release["ate"] - now.timestamp()))
            if mode.next and not mode.active:
                left = (mode.next - now).total_seconds()
                if left <= WARN_S and warned != int(mode.next.timestamp()):
                    warned = int(mode.next.timestamp())
                    notify("Modo Estudo em breve", f"Começa às {mode.next:%H:%M}. Salve o que estiver aberto nos apps bloqueados.")
                wait = min(wait, max(1, left - WARN_S if left > WARN_S else left))
        was_blocking = mode.blocking

        try:
            ready, _, _ = select.select([rd] + ([events] if events else []), [], [], wait)
        except InterruptedError:
            continue
        if rd in ready:  # something changed (the menu, "agora", "liberar", "trancar"): look now
            try:
                rd.recv(4096)
            except OSError:
                pass
            last_sweep = 0.0
        if events is not None and events in ready:
            try:
                chunk = events.recv(65536)
            except OSError:
                chunk = b""
            if not chunk:  # Hyprland went away: connect again on the next pass
                events.close()
                events = None
                buf = b""
                continue
            buf += chunk
            *lines, buf = buf.split(b"\n")
            # a window opened: look now instead of waiting for the next pass
            if any(l.startswith(b"openwindow>>") for l in lines):
                closer.sweep(Mode(datetime.now()))
                last_sweep = time.time()


def poke():
    try:
        with open(PIDFILE) as f:
            os.kill(int(f.read().strip()), signal.SIGUSR1)
    except (OSError, ValueError):
        pass


# ---------- commands ----------

def fmt(ts):
    t = datetime.fromtimestamp(ts)
    return t.strftime("%H:%M") if t.date() == datetime.now().date() else t.strftime("%a %d/%m %H:%M")


def cmd_estado(_):
    m = Mode(datetime.now())
    print("Modo Estudo:", f"LIGADO até {fmt(m.end.timestamp())}" if m.active else "desligado")
    if m.next:
        print("Próxima sessão:", fmt(m.next.timestamp()))
    if m.release:
        what = "tudo" if m.release.get("tudo") else ", ".join((m.release.get("apps") or []) + (m.release.get("sites") or []))
        print(f"Liberado até {fmt(m.release['ate'])}: {what} ({m.release.get('motivo', '')})")
    if m.pending:
        print("Há mudanças na agenda que só valem a partir de amanhã (as que afrouxam).")
    print("Apps bloqueados:", ", ".join(a["nome"] for a in m.apps) or "nenhum")
    print("Sites bloqueados:", ", ".join(m.sites) or "nenhum",
          "" if os.access(HELPER, os.X_OK) else "(ajudante de sites não instalado: rode scripts/estudo/instalar-sites.sh com sudo)")


def cmd_agora(args):
    minutes = max(1, min(MAX_MIN, args.minutos))
    cur = load(SESSAO) or {}
    until = max(cur.get("ate", 0), time.time() + minutes * 60)
    save(SESSAO, {"ate": until})
    poke()
    print(f"Sessão de estudo até {fmt(until)}.")


def cmd_liberar(args):
    if not (args.tudo or args.app or args.site):
        sys.exit("Diga o que liberar: --tudo, --app ID ou --site DOMÍNIO.")
    if len(args.motivo.strip()) < 10:
        sys.exit("O motivo precisa ser de verdade (pelo menos uma frase).")
    m = Mode(datetime.now())
    known = {a["id"] for a in merged_apps(m.vigente["apps"], m.agenda["apps"])}
    for a in args.app:
        if a not in known:
            sys.exit(f"App desconhecido: {a}. Os da lista: {', '.join(sorted(known))}")
    if args.min:
        until = time.time() + args.min * 60
    elif m.end:
        until = m.end.timestamp()  # until the session on now ends
    else:
        until = time.time() + 3600
    rel = {"ate": until, "tudo": bool(args.tudo), "apps": args.app, "sites": [clean_domain(s) for s in args.site if clean_domain(s)], "motivo": args.motivo.strip()}
    save(LIBERADO, rel)
    what = "tudo" if rel["tudo"] else ", ".join(rel["apps"] + rel["sites"])
    with open(HISTORICO, "a") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M}\tliberado: {what}\taté {fmt(until)}\t{rel['motivo']}\n")
    poke()
    notify("Modo Estudo: liberação", f"{what} até {fmt(until)}. Motivo: {rel['motivo']}")
    print(f"Liberado ({what}) até {fmt(until)}.")


def cmd_trancar(_):
    try:
        os.remove(LIBERADO)
    except OSError:
        pass
    with open(HISTORICO, "a") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M}\tliberação encerrada\n")
    poke()
    print("Liberação encerrada.")


def cmd_historico(_):
    try:
        with open(HISTORICO) as f:
            print(f.read(), end="")
    except OSError:
        print("Nenhuma liberação até agora.")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Mosaic OS: modo Estudo")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("daemon").set_defaults(fn=lambda _: daemon())
    sub.add_parser("estado").set_defaults(fn=cmd_estado)
    a = sub.add_parser("agora")
    a.add_argument("minutos", type=int)
    a.set_defaults(fn=cmd_agora)
    l = sub.add_parser("liberar")
    l.add_argument("--motivo", required=True)
    l.add_argument("--tudo", action="store_true")
    l.add_argument("--app", action="append", default=[])
    l.add_argument("--site", action="append", default=[])
    l.add_argument("--min", type=int, default=0)
    l.set_defaults(fn=cmd_liberar)
    sub.add_parser("trancar").set_defaults(fn=cmd_trancar)
    sub.add_parser("historico").set_defaults(fn=cmd_historico)
    args = p.parse_args()
    os.makedirs(STATE, exist_ok=True)
    args.fn(args)
