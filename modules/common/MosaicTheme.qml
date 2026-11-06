pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mosaic OS themes. A theme is colours AND shapes, for the shell (Quickshell)
// and Hyprland (borders, background, window corners); apps are left alone.
// - roundness: how round things are. 1 = Mosaic (soft pills); Gruvbox is boxy
//   (0.2: a 20 px curve becomes 4 px). Every radius in the shell goes through
//   r(px), and Appearance.rounding (the ii's) is scaled by it too.
// - "mosaic": the colours come from the wallpaper (Matugen), as before. Matugen
//   is only the way this theme gets its colours.
// - "gruvbox": a fixed palette (themes/gruvbox.json, Gruvbox dark medium).
// The choice is kept in ~/.config/mosaic-os/theme. MaterialThemeLoader reads the
// right colours file; this singleton also paints Hyprland.
Singleton {
    id: root

    readonly property var themes: [
        // swatches: the four blocks of the Mosaic mark, in the theme's tones
        { id: "mosaic", name: "Mosaic", hint: "cores do papel de parede", file: "", roundness: 1, style: "soft" },
        { id: "gruvbox", name: "Gruvbox", hint: "escuro médio", file: Quickshell.shellPath("themes/gruvbox.json"),
          swatches: ["#fe8019", "#b8bb26", "#83a598", "#ebdbb2"], base: "#282828", roundness: 0.2, style: "brutal",
          // neo-brutalist: cream outlines, a hard orange shadow, flat colours
          ink: "#ebdbb2", shadowColor: "#d65d0e",
          // the terminal (kitty): Gruvbox dark
          terminal: `background #282828
foreground #ebdbb2
cursor #ebdbb2
cursor_text_color #282828
selection_background #504945
selection_foreground #ebdbb2
url_color #83a598
color0 #282828
color8 #928374
color1 #cc241d
color9 #fb4934
color2 #98971a
color10 #b8bb26
color3 #d79921
color11 #fabd2f
color4 #458588
color12 #83a598
color5 #b16286
color13 #d3869b
color6 #689d6a
color14 #8ec07c
color7 #a89984
color15 #ebdbb2
color253 #665c54
color254 #7c6f64
color255 #a89984`,
          hypr: { active: "rgba(fe8019aa)", inactive: "rgba(50494566)", background: "rgba(1d2021ff)", rounding: 3 } }
    ]
    property string current: "mosaic"
    readonly property var theme: root.themes.find(t => t.id === root.current) ?? root.themes[0]
    readonly property string colorsFile: root.theme.file // "" = the Matugen file
    readonly property real roundness: root.theme.roundness ?? 1
    // The style of the shapes:
    // - "soft" (Mosaic): glass, gradients, thin hairlines, soft curves
    // - "brutal" (Gruvbox): flat colours, thick outlines (`border` px in `ink`),
    //   a hard shadow offset by `shadow` px (no blur), things sink into their
    //   shadow when pressed, and a few labels tilt like stickers (`tilt` degrees)
    readonly property bool brutal: root.theme.style === "brutal"
    readonly property real border: root.brutal ? 2 : 0
    readonly property real shadow: root.brutal ? 4 : 0
    readonly property color ink: root.theme.ink ?? "transparent"
    readonly property color shadowColor: root.theme.shadowColor ?? "transparent"
    readonly property real tilt: root.brutal ? -2.5 : 0
    // brutal themes paint solid surfaces (the ii layers are see-through and let
    // the wallpaper tint them): the theme's background, and a raised one
    readonly property color slab: Appearance.m3colors.m3background
    readonly property color slabRaised: Appearance.m3colors.m3surfaceContainer
    // a radius in this theme's shape (a soft Mosaic curve, a square Gruvbox corner)
    function r(px) { return Math.max(0, Math.round(px * root.roundness)); }

    function set(id) {
        if (id === root.current || !root.themes.some(t => t.id === id))
            return;
        root.current = id;
        stateFile.setText(id);
        root.paintHyprland();
        root.paintTerminal();
    }

    // The terminal (kitty): kitty.conf includes ~/.config/mosaic-os/terminal-theme.conf
    // AFTER the Matugen colours, and in kitty what comes later wins. A fixed theme
    // writes its palette there; the Mosaic theme leaves it empty. Then every open
    // kitty is told to reload its config (SIGUSR1).
    function paintTerminal() {
        terminalFile.setText((root.theme.terminal ?? "") + "\n");
        sequencesFile.setText(root.sequencesFor(root.theme.terminal ?? ""));
    }
    // The same palette as terminal escape codes (OSC 4/10/11/12/17). Every new fish
    // prints the ii's wallpaper codes at start (config.fish), which repaint the
    // terminal over kitty's config; with a fixed theme it prints these instead.
    // "" (Mosaic theme): the wallpaper codes are used again.
    function sequencesFor(palette) {
        if (palette === "")
            return "";
        const esc = "\x1b]", end = "\x1b\\";
        const osc = { foreground: "10", background: "11", cursor: "12", selection_background: "17" };
        let out = "";
        for (const line of palette.split("\n")) {
            const m = line.trim().match(/^(\w+)\s+(#[0-9a-fA-F]{6})$/);
            if (!m)
                continue;
            const n = m[1].match(/^color(\d+)$/);
            if (n)
                out += `${esc}4;${n[1]};${m[2]}${end}`;
            else if (osc[m[1]])
                out += `${esc}${osc[m[1]]};${m[2]}${end}`;
        }
        return out;
    }
    // repaint the shells that are already open (what the ii does on wallpaper change)
    function pushToOpenTerminals() {
        const file = root.theme.terminal ? Quickshell.env("HOME") + "/.config/mosaic-os/terminal-sequences.txt"
            : Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/terminal/sequences.txt";
        Quickshell.execDetached(["sh", "-c", `for f in /dev/pts/[0-9]*; do [ -w "$f" ] && cat '${file}' > "$f" 2>/dev/null & done`]);
    }
    FileView {
        id: sequencesFile
        path: Quickshell.env("HOME") + "/.config/mosaic-os/terminal-sequences.txt"
        printErrors: false
        onSaved: root.pushToOpenTerminals()
    }
    FileView {
        id: terminalFile
        path: Quickshell.env("HOME") + "/.config/mosaic-os/terminal-theme.conf"
        printErrors: false
        onSaved: Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"])
    }

    // Hyprland: a fixed theme sets the border and background colours live; the
    // Mosaic theme reloads the config, which brings back Matugen's colors.lua.
    function paintHyprland() {
        const h = root.theme.hypr;
        if (h)
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({ general = { col = { active_border = "${h.active}", inactive_border = "${h.inactive}" } }, misc = { background_color = "${h.background}" }, decoration = { rounding = ${h.rounding} } })`]);
        else
            Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
    }

    // qs -c mosaic ipc call theme set gruvbox|mosaic
    IpcHandler {
        target: "theme"
        function set(id: string): void { root.set(id); }
        function get(): string { return root.current; }
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.config/mosaic-os/theme"
        printErrors: false // only exists after the first choice
        onLoadFailed: root.paintTerminal()
        onLoaded: {
            const id = text().trim();
            if (root.themes.some(t => t.id === id)) {
                root.current = id;
                if (id !== "mosaic")
                    root.paintHyprland(); // after a restart, Hyprland has the config colours again
                root.paintTerminal();
            }
        }
    }
}
