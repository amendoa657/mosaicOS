pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The liquid glass of the widgets and the dock (Aparência and Dock tabs:
// Config.options.mosaicWidgets / mosaicDock, glass = strength, chroma = chromatic
// aberration). The widgets' preset goes on the island and both sidebars (the
// desktop widgets live in the wallpaper layer, which has no glass). hyprglass only takes presets from the Hyprland config, so this
// writes both presets to ~/.config/mosaic-os/glass.lua (hypr/mosaic.lua runs it)
// and reloads the config. It waits 700 ms after the last change, so dragging a
// slider reloads once, not on every step. After a reload, a fixed theme's
// Hyprland colours are painted again (the reload brings back the config ones).
Singleton {
    id: root

    readonly property var island: Config.options?.mosaicWidgets
    readonly property var dock: Config.options?.mosaicDock
    // one string with every value, so any change re-applies
    readonly property string signature: `${island?.glass}/${island?.chroma}/${dock?.glass}/${dock?.chroma}`
    readonly property string path: Quickshell.env("HOME") + "/.config/mosaic-os/glass.lua"

    function load() {} // called once so the singleton starts watching

    // base: the preset at strength 1; k: strength; c: chromatic aberration
    // multiplier. Everything grows with k (with ceilings); the rainbow edges
    // follow c on their own.
    // layers: [[namespace, mask threshold], ...], all with this preset
    function presetLua(name, layers, base, k, c) {
        if (k <= 0.01)
            return layers.map(l => `hg.layer("${l[0]}", { enabled = 0 })\n`).join("");
        const v = (key, max) => Math.min(max, base[key] * k).toFixed(3);
        return `hg.preset("${name}", {
    enabled = 1,
    blur_strength = ${v("blur", 0.8)},
    refraction_strength = ${v("refraction", 7)},
    lens_distortion = ${v("lens", 2)},
    chromatic_aberration = ${Math.min(3.5, base.chroma * c).toFixed(3)},
    fresnel_strength = ${v("fresnel", 3.5)},
    specular_strength = ${v("specular", 6)},
    saturation = ${(1 + (base.saturation - 1) * k).toFixed(3)},
    vibrancy = ${v("vibrancy", 1)},
    edge_thickness = ${v("edge", 0.24)},
})
` + layers.map(l => `hg.layer("${l[0]}", { preset = "${name}", mask_threshold = ${l[1]} })\n`).join("");
    }
    readonly property var islandBase: ({ blur: 0.35, refraction: 2.2, lens: 0.6, chroma: 0.9, fresnel: 1.2, specular: 2.6, saturation: 1.45, vibrancy: 0.4, edge: 0.08 })
    readonly property var dockBase: ({ blur: 0.22, refraction: 4.8, lens: 1.35, chroma: 1.9, fresnel: 2.4, specular: 4.2, saturation: 1.75, vibrancy: 0.75, edge: 0.16 })

    function fileText() {
        return "-- written by the Mosaic OS Aparência and Dock tabs\nlocal hg = hl.plugin.hyprglass\n"
            + root.presetLua("widgets", [["quickshell:island", 0.05], ["quickshell:sidebarLeft", 0.3], ["quickshell:sidebarRight", 0.3]], root.islandBase, root.island?.glass ?? 1, root.island?.chroma ?? 1)
            + root.presetLua("doca", [["quickshell:dock", 0.12]], root.dockBase, root.dock?.glass ?? 1, root.dock?.chroma ?? 1);
    }

    // changes during startup are just the saved values being loaded: ignore them
    property bool ready: false
    Timer { running: true; interval: 4000; onTriggered: root.ready = true }
    onSignatureChanged: if (root.ready) applyLater.restart()
    Timer {
        id: applyLater
        interval: 700
        onTriggered: file.setText(root.fileText())
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
