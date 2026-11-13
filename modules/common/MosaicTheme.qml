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
// - "horizonte": a fixed dark palette (themes/horizonte.json) taken from the
//   first screen of the Claude Opus 5.5 page: a navy sky, an orange horizon,
//   an almost black ground, cream text, serif titles and film grain. Choosing
//   it also sets its wallpaper (`wallpaper`).
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
color255 #fe8019
color254 #af3a03
color253 #b8bb26
color252 #79740e
color251 #83a598
color250 #076678
color249 #fb4934
color248 #9d0006
color232 #282828
color233 #fbf1c7
color234 #282828
color235 #fbf1c7
color236 #282828
color237 #fbf1c7
color238 #282828
color239 #fbf1c7
color240 #282828
color243 #fe8019
color244 #fb4934
color245 #665c54`,
          hypr: { active: "rgba(fe8019aa)", inactive: "rgba(50494566)", background: "rgba(1d2021ff)", rounding: 3 } },
        { id: "horizonte", name: "Horizonte", hint: "pôr do sol anos 70", file: Quickshell.shellPath("themes/horizonte.json"),
          swatches: ["#e8673a", "#f2c94c", "#79a5d4", "#f2ede4"], base: "#12100d", roundness: 0.6, style: "retro",
          ink: "#f2ede4", fontDisplay: "Fraunces",
          wallpaper: Quickshell.env("HOME") + "/Imagens/Wallpapers/horizonte.jpg",
          // the terminal (kitty): cream on the ground's near black, the sky's blues
          terminal: `background #12100d
foreground #f2ede4
cursor #e8673a
cursor_text_color #12100d
selection_background #332c25
selection_foreground #f2ede4
url_color #79a5d4
color0 #12100d
color8 #5c5348
color1 #d9534a
color9 #ef6f5e
color2 #8fa86a
color10 #a9c47f
color3 #e8a84c
color11 #f2c94c
color4 #5f8cc0
color12 #79a5d4
color5 #b5739a
color13 #cf8fb4
color6 #6fa3a0
color14 #8cc0bb
color7 #c8bdae
color15 #f2ede4
color255 #e8673a
color254 #7a2e14
color253 #f2c94c
color252 #6b5214
color251 #79a5d4
color250 #284766
color249 #ef6f5e
color248 #7d2620
color232 #16110d
color233 #fde6d8
color234 #1a1408
color235 #fff1c9
color236 #0e1622
color237 #dceaff
color238 #16110d
color239 #fde2dd
color240 #16110d
color243 #e8673a
color244 #ef6f5e
color245 #3f372e`,
          hypr: { active: "rgba(e8673aaa)", inactive: "rgba(332c2566)", background: "rgba(0e0c0aff)", rounding: 8 } },
        { id: "macos", name: "macOS", hint: "vidro líquido no talo", file: Quickshell.shellPath("themes/macos.json"),
          swatches: ["#0a84ff", "#bf5af2", "#30d158", "#f5f5f7"], base: "#1e1e1e", roundness: 1.1, style: "mac",
          ink: "#f5f5f7", fontUi: "Inter Variable", fontDisplay: "Inter Display",
          // the terminal (kitty): macOS Terminal's dark profile, with the system colours
          terminal: `background #1e1e1e
foreground #f5f5f7
cursor #0a84ff
cursor_text_color #1e1e1e
selection_background #3a3a3c
selection_foreground #f5f5f7
url_color #64d2ff
color0 #1e1e1e
color8 #636366
color1 #ff453a
color9 #ff6961
color2 #30d158
color10 #66e283
color3 #ffd60a
color11 #ffe55c
color4 #0a84ff
color12 #64aaff
color5 #bf5af2
color13 #da8fff
color6 #64d2ff
color14 #99e3ff
color7 #c7c7cc
color15 #f5f5f7
color255 #0a84ff
color254 #0a3d75
color253 #bf5af2
color252 #4b2463
color251 #30d158
color250 #0f5224
color249 #ff453a
color248 #7a1a14
color232 #1c1c1e
color233 #d6e8ff
color234 #1c1c1e
color235 #f3dcff
color236 #1c1c1e
color237 #c9f5d3
color238 #1c1c1e
color239 #ffdad6
color240 #1c1c1e
color243 #0a84ff
color244 #ff453a
color245 #48484a`,
          hypr: { active: "rgba(ffffff33)", inactive: "rgba(ffffff14)", background: "rgba(1e1e1eff)", rounding: 12 } }
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
    // - "retro" (Horizonte): the soft shapes, plus film grain on the island and
    //   the dock (`grain`: how strong), and serif titles
    readonly property bool retro: root.theme.style === "retro"
    // macOS: everything as glass, Apple's shapes and type
    readonly property bool mac: root.theme.style === "mac"
    readonly property real grain: root.retro ? 0.07 : 0
    // The shell's own grain: none while the apps' grain (a Hyprland screen shader,
    // MosaicScreenGrain) is on, since that one already covers the shell too
    readonly property real shellGrain: MosaicScreenGrain.wanted ? 0 : root.grain
    // ...and how much of it each part gets (Ilha, Aparência and Dock tabs)
    readonly property var widgets: Config.options?.mosaicWidgets
    readonly property real grainIsland: root.shellGrain * (Config.options?.mosaicIsland?.grain ?? 1)
    readonly property real grainSidebars: root.shellGrain * (root.widgets?.grainSidebars ?? 1)
    readonly property real grainDesktop: root.shellGrain * (root.widgets?.grainDesktop ?? 1)
    readonly property real grainPicker: root.shellGrain * (root.widgets?.grainPicker ?? 1)
    readonly property real grainDock: root.shellGrain * (Config.options?.mosaicDock?.grain ?? 1)
    // The widgets' surface (sidebars, desktop widgets), from the Aparência tab
    // (the island does the same with its own Ilha tab): `base` pulled toward black by `darkness`, as solid as `opacity`.
    function widgetFill(base) {
        const d = root.widgets?.darkness ?? 0.55;
        return Qt.rgba(base.r * (1 - d), base.g * (1 - d), base.b * (1 - d), root.paneAlpha(root.widgets?.opacity ?? 0.9));
    }
    // macOS: the panes stay thin so the liquid glass under them shows (at most 30%)
    function paneAlpha(a) { return root.mac ? Math.min(a, 0.14) : a; }
    // Fonts: `fontUi` for text, `fontDisplay` for titles (the clock, headers).
    // A theme's display font is used only if it is installed (Fraunces comes from
    // the AUR: ttf-fraunces-variable); until then, a serif that is.
    // a theme may ask for its own text font (macOS: Inter, the free cousin of SF Pro), if installed
    readonly property string fontUi: root.theme.fontUi && Qt.fontFamilies().includes(root.theme.fontUi) ? root.theme.fontUi : "Space Grotesk"
    readonly property string fontDisplay: {
        const want = root.theme.fontDisplay;
        if (!want)
            return root.fontUi;
        const installed = Qt.fontFamilies();
        return installed.includes(want) ? want : (installed.includes("Noto Serif") ? "Noto Serif" : "serif");
    }
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
        // Neovim, the Mosaic Store and Zen (their Matugen templates):
        // - a theme with its own wallpaper puts it up (dark mode: the theme is dark
        //   only); switchwall.sh then runs theme-apps.sh, which paints them in the theme
        // - another fixed theme: theme-apps.sh straight away
        // - the Mosaic theme: Matugen again from the current wallpaper
        if (root.theme.wallpaper)
            wallpaperProc.running = true;
        else if (root.theme.file)
            Quickshell.execDetached([Quickshell.shellPath("scripts/colors/theme-apps.sh"), id]);
        else
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"]);
    }
    // The wallpaper script reloads Hyprland, which brings back the config's border
    // colours: once it is done, the theme's are painted again.
    Process {
        id: wallpaperProc
        command: [Directories.wallpaperSwitchScriptPath, "--image", root.theme.wallpaper ?? "", "--mode", "dark"]
        onExited: root.paintHyprland()
    }

    // The 256-colour slots 232-255 carry the theme's Material roles, like the ii's
    // Matugen template (255 primary, 252 secondary container...): the starship
    // prompt paints its pills with them, so a theme sets them all.
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

    // qs -c mosaic ipc call theme set gruvbox|horizonte|mosaic
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
