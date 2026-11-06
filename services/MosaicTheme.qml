pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mosaic OS themes. A theme is a set of colours for the shell (Quickshell) and
// Hyprland (borders, background); apps are left alone.
// - "mosaic": the colours come from the wallpaper (Matugen), as before. Matugen
//   is only the way this theme gets its colours.
// - "gruvbox": a fixed palette (themes/gruvbox.json, Gruvbox dark medium).
// The choice is kept in ~/.config/mosaic-os/theme. MaterialThemeLoader reads the
// right colours file; this singleton also paints Hyprland.
Singleton {
    id: root

    readonly property var themes: [
        // swatches: the four blocks of the Mosaic mark, in the theme's tones
        { id: "mosaic", name: "Mosaic", hint: "cores do papel de parede", file: "" },
        { id: "gruvbox", name: "Gruvbox", hint: "escuro médio", file: Quickshell.shellPath("themes/gruvbox.json"),
          swatches: ["#fe8019", "#b8bb26", "#83a598", "#ebdbb2"], base: "#282828",
          hypr: { active: "rgba(fe8019aa)", inactive: "rgba(50494566)", background: "rgba(1d2021ff)" } }
    ]
    property string current: "mosaic"
    readonly property var theme: root.themes.find(t => t.id === root.current) ?? root.themes[0]
    readonly property string colorsFile: root.theme.file // "" = the Matugen file

    function set(id) {
        if (id === root.current || !root.themes.some(t => t.id === id))
            return;
        root.current = id;
        stateFile.setText(id);
        root.paintHyprland();
    }

    // Hyprland: a fixed theme sets the border and background colours live; the
    // Mosaic theme reloads the config, which brings back Matugen's colors.lua.
    function paintHyprland() {
        const h = root.theme.hypr;
        if (h)
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({ general = { col = { active_border = "${h.active}", inactive_border = "${h.inactive}" } }, misc = { background_color = "${h.background}" } })`]);
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
        onLoaded: {
            const id = text().trim();
            if (root.themes.some(t => t.id === id)) {
                root.current = id;
                if (id !== "mosaic")
                    root.paintHyprland(); // after a restart, Hyprland has the config colours again
            }
        }
    }
}
