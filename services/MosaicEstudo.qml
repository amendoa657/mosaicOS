pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The study mode ("modo Estudo"), seen from the shell: the schedule and the
// block lists (agenda.json, which the Estudo tab edits) and what is going on
// right now (estado.json, written by the service).
// The shell blocks nothing: the service does (scripts/estudo/estudo.py, its
// own systemd user unit), so restarting the shell does not turn the mode off.
// No timer here either: the service rewrites estado.json when something
// changes, and the FileView notices.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/estudo/estudo.py")
    readonly property var dayNames: ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]

    property var agenda: ({ dias: [], apps: [], sites: [] })
    property var estado: ({})
    property bool installed: false // the service has run at least once (estado.json exists)
    readonly property bool active: root.estado.ativo ?? false
    readonly property real until: (root.estado.ate ?? 0) * 1000    // ms since epoch
    readonly property real next: (root.estado.proximo ?? 0) * 1000
    readonly property var release: root.estado.liberado ?? null
    readonly property bool pending: root.estado.pendente ?? false
    readonly property bool sitesInstalled: root.estado.sitesInstalado ?? false
    // the tab is read-only while a session is on (a full release does not unlock it)
    readonly property bool locked: root.active

    function clock(ms) { return Qt.formatTime(new Date(ms), "HH:mm"); }
    // "14:00" + 135 min -> "16:15"
    function endOf(start, minutes) {
        const p = start.split(":");
        const t = (parseInt(p[0]) * 60 + parseInt(p[1]) + minutes) % 1440;
        return String(Math.floor(t / 60)).padStart(2, "0") + ":" + String(t % 60).padStart(2, "0");
    }
    function shift(start, by) {
        const p = start.split(":");
        const t = ((parseInt(p[0]) * 60 + parseInt(p[1]) + by) % 1440 + 1440) % 1440;
        return String(Math.floor(t / 60)).padStart(2, "0") + ":" + String(t % 60).padStart(2, "0");
    }
    // 25 -> "25 min", 90 -> "1h30", 120 -> "2h"
    function span(minutes) {
        const h = Math.floor(minutes / 60), m = minutes % 60;
        return h === 0 ? m + " min" : m === 0 ? h + "h" : h + "h" + String(m).padStart(2, "0");
    }
    // read both files again: a file that did not exist when the shell started is
    // not being watched yet (the tab calls this when it opens)
    function refresh() {
        agendaFile.reload();
        estadoFile.reload();
    }

    // every change goes through here: a new object (so the bindings see it), the
    // file, and a nudge to the service
    function save(next) {
        if (root.locked || root.agenda.dias.length !== 7)
            return;
        root.agenda = next;
        agendaFile.setText(JSON.stringify(next, null, 1));
    }
    function setDay(i, change) {
        const dias = root.agenda.dias.map((d, j) => j === i ? Object.assign({}, d, change) : d);
        root.save(Object.assign({}, root.agenda, { dias: dias }));
    }
    function removeApp(id) { root.save(Object.assign({}, root.agenda, { apps: root.agenda.apps.filter(a => a.id !== id) })); }
    function hasApp(id) { return root.agenda.apps.some(a => a.id === id); }
    // an installed app: its windows are known by the desktop id, its StartupWMClass
    // and the last part of the id (org.kde.haruna -> haruna), as regular expressions
    function addApp(entry) {
        if (!entry || root.hasApp(entry.id))
            return;
        const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const names = [entry.id, entry.startupClass, entry.id.substring(entry.id.lastIndexOf(".") + 1)].filter(n => n && n.length > 1);
        const classes = names.map(esc).filter((c, i, all) => all.indexOf(c) === i);
        root.save(Object.assign({}, root.agenda, { apps: root.agenda.apps.concat([{ id: entry.id, nome: entry.name, classes: classes, procs: [] }]) }));
    }
    function removeSite(d) { root.save(Object.assign({}, root.agenda, { sites: root.agenda.sites.filter(s => s !== d) })); }
    // "https://www.Site.com/x" -> "site.com"; false when it is not a domain
    function addSite(text) {
        const d = text.trim().toLowerCase().replace(/^[a-z]+:\/\//, "").split("/")[0].replace(/^www\./, "");
        if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/.test(d))
            return false;
        if (!root.agenda.sites.includes(d))
            root.save(Object.assign({}, root.agenda, { sites: root.agenda.sites.concat([d]) }));
        return true;
    }
    // a session right now (there is no way back from the shell)
    function startNow(minutes) { Quickshell.execDetached([root.script, "agora", String(minutes)]); }

    function nudge() { Quickshell.execDetached(["systemctl", "--user", "kill", "-s", "USR1", "mosaic-estudo.service"]); }

    // from a terminal: what the shell is seeing, and a day of the schedule
    // (0 = Monday), which goes the same way as the tab (so not during a session)
    //   qs -c mosaic ipc call mosaicEstudo estado
    //   qs -c mosaic ipc call mosaicEstudo dia 0 true 14:00 120
    IpcHandler {
        target: "mosaicEstudo"
        function dia(i: int, ativo: bool, inicio: string, minutos: int): string {
            if (root.locked)
                return "travado: há uma sessão de estudo ligada";
            if (i < 0 || i > 6 || !/^([01]\d|2[0-3]):[0-5]\d$/.test(inicio) || minutos < 15 || minutos > 960)
                return "uso: dia 0..6 true|false HH:MM minutos(15..960)";
            root.setDay(i, { ativo: ativo, inicio: inicio, minutos: minutos });
            return `${root.dayNames[i]}: ${ativo ? inicio + " até " + root.endOf(inicio, minutos) : "desligado"}`;
        }
        function estado(): string {
            return JSON.stringify({
                instalado: root.installed, ativo: root.active, ate: root.until ? root.clock(root.until) : "",
                proximo: root.next ? root.clock(root.next) : "", liberado: root.release, pendente: root.pending,
                dias: root.agenda.dias.filter(d => d.ativo).length, apps: root.agenda.apps.length, sites: root.agenda.sites.length
            });
        }
    }

    FileView {
        id: agendaFile
        path: Quickshell.env("HOME") + "/.config/mosaic-os/estudo/agenda.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onSaved: root.nudge()
        onLoaded: {
            try {
                const a = JSON.parse(agendaFile.text());
                if (a && a.dias && a.dias.length === 7 && JSON.stringify(a) !== JSON.stringify(root.agenda))
                    root.agenda = a;
            } catch (e) {}
        }
    }
    FileView {
        id: estadoFile
        path: Quickshell.env("HOME") + "/.local/state/mosaic-os/estudo/estado.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.estado = JSON.parse(estadoFile.text());
                root.installed = true;
            } catch (e) {}
        }
    }
}
