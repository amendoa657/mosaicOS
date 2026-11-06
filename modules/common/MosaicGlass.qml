pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The island's liquid glass strength (Ilha tab, Config.options.mosaicIsland.glass).
// hyprglass only takes presets from the Hyprland config, so this writes the
// island's preset to ~/.config/mosaic-os/glass.lua (hypr/mosaic.lua runs it) and
// reloads the config. It waits 700 ms after the last change, so dragging the
// slider reloads once, not on every step. After a reload, a fixed theme's
// Hyprland colours are painted again (the reload brings back the config ones).
Singleton {
    id: root

    readonly property real strength: Config.options?.mosaicIsland?.glass ?? 1
    readonly property string path: Quickshell.env("HOME") + "/.config/mosaic-os/glass.lua"

    function load() {} // called once so the singleton starts watching

    // the "vivo" preset (hypr/mosaic.lua) scaled by the strength: the lens,
    // refraction, rainbow edges and shine grow; blur grows a little less
    function presetLua(k) {
        if (k <= 0.01)
            return `hl.plugin.hyprglass.layer("quickshell:island", { enabled = 0 })\n`;
        const v = (base, max) => Math.min(max, base * k).toFixed(3);
        return `-- written by the Mosaic OS Ilha tab (glass strength ${k.toFixed(2)})
local hg = hl.plugin.hyprglass
hg.preset("ilha", {
    enabled = 1,
    blur_strength = ${v(0.35, 0.8)},
    refraction_strength = ${v(2.2, 6)},
    lens_distortion = ${v(0.6, 1.6)},
    chromatic_aberration = ${v(0.9, 2.4)},
    fresnel_strength = ${v(1.2, 3)},
    specular_strength = ${v(2.6, 5.5)},
    saturation = ${(1 + 0.45 * k).toFixed(3)},
    vibrancy = ${v(0.4, 0.9)},
    edge_thickness = ${v(0.08, 0.2)},
})
hg.layer("quickshell:island", { preset = "ilha", mask_threshold = 0.05 })
`;
    }

    // changes during startup are just the saved value being loaded: ignore them
    property bool ready: false
    Timer { running: true; interval: 4000; onTriggered: root.ready = true }
    onStrengthChanged: if (root.ready) applyLater.restart()
    Timer {
        id: applyLater
        interval: 700
        onTriggered: file.setText(root.presetLua(root.strength))
    }
    FileView {
        id: file
        path: root.path
        printErrors: false
        onSaved: {
            Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
            repaint.restart();
        }
    }
    Timer {
        id: repaint
        interval: 600
        onTriggered: if (MosaicTheme.theme.hypr) MosaicTheme.paintHyprland()
    }
}
