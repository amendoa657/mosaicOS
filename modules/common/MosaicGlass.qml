pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The liquid glass of the island, the widgets and the dock (Ilha, Aparência and
// Dock tabs: Config.options.mosaicIsland / mosaicWidgets / mosaicDock, glass =
// strength, chroma = chromatic aberration). The widgets' preset goes on both
// sidebars; the desk of widgets (desk/, the mosaic-desk layer) gets it only in macOS. hyprglass only takes presets from the Hyprland config, so this
// writes both presets to ~/.config/mosaic-os/glass.lua (hypr/mosaic.lua runs it)
// and reloads the config. It waits 700 ms after the last change, so dragging a
// slider reloads once, not on every step. After a reload, a fixed theme's
// Hyprland colours are painted again (the reload brings back the config ones).
Singleton {
    id: root

    readonly property var island: Config.options?.mosaicIsland
    readonly property var widgets: Config.options?.mosaicWidgets
    readonly property var dock: Config.options?.mosaicDock
    // one string with every value, so any change re-applies
    readonly property string signature: `${island?.glass}/${island?.chroma}/${widgets?.glass}/${widgets?.chroma}/${dock?.glass}/${dock?.chroma}/${MosaicTheme.current}`
    // macOS theme: every glass turned all the way up ("até o talo"), the widgets with
    // the dock's strong lens, and a low mask threshold so even a faint pane is glass
    readonly property bool mac: MosaicTheme.mac
    readonly property real boost: 1
    // macOS's glass: strong lens and light, but neutral (Apple's glass does not
    // tint what is behind it), with only a trace of rainbow
    // macOS: the "lens" mode of hyprglass, like Apple's Liquid Glass: a clear, flat
    // centre (little blur, no dome), the edge bending the picture behind it
    // (edge_height + refraction only at the rim), a thin lit line, no white glow.
    // Every value inside hyprglass's ranges (0..1): past them the edge burns white.
    // k (the Aparência/Ilha/Dock glass slider) scales the bend.
    // layers: [[namespace, mask threshold, mask mode], ...]. "contour" gives every
    // shape the layer draws its own edge, bend and light (the desk is one layer
    // as big as the screen: without it the lens edge sat on the screen's edge)
    function macLua(name, layers, k, edgePx, heightPx) {
        if (k <= 0.01)
            return layers.map(l => `hg.layer("${l[0]}", { enabled = 0 })\n`).join("");
        const c = (v, max) => Math.min(max, v).toFixed(3);
        return `hg.preset("${name}", {
    enabled = 1,
    blur_strength = 0.35,
    blur_iterations = 2,
    refraction_strength = ${c(0.85 * k, 1)},
    refraction_spread = 0.0,
    refraction_flow = 0.35,
    lens_distortion = 0.04,
    edge_thickness_px = ${edgePx},
    edge_height = ${c((heightPx ?? 24) * k, 60)},
    fresnel_reflection = 0.3,
    chromatic_aberration = 0.12,
    fresnel_strength = 0.18,
    specular_strength = 0.35,
    bevel_strength = 0.5,
    bevel_size = 1.5,
    tint_color = 0x00000000,
    brightness = 1.0,
    contrast = 1.0,
    saturation = 1.05,
    vibrancy = 0.12,
    adaptive_dim = 0.12,
    adaptive_boost = 0.0,
})
` + layers.map(l => `hg.layer("${l[0]}", { preset = "${name}", mask_threshold = ${l[1]}${l[2] ? `, mask_mode = "${l[2]}"` : ""} })\n`).join("");
    }
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
        const head = "-- written by the Mosaic OS Ilha, Aparência and Dock tabs\nlocal hg = hl.plugin.hyprglass\n";
        if (root.mac)
            return head
                + root.macLua("ilha", [["quickshell:island", 0.05]], root.island?.glass ?? 1, 10)
                + root.macLua("widgets", [["quickshell:sidebarLeft", 0.06, "contour"], ["quickshell:sidebarRight", 0.06, "contour"], ["mosaic-desk", 0.06, "contour"], ["quickshell:mosaicSettings", 0.06, "contour"]], root.widgets?.glass ?? 1, 16)
                + root.macLua("doca", [["quickshell:dock", 0.06, "contour"]], root.dock?.glass ?? 1, 18)
                // the menu bar: the same lens, thin (it is 30 px tall), along its whole width
                + root.macLua("barra", [["quickshell:topbar", 0.06]], root.widgets?.glass ?? 1, 8, 10);
        return head
            + root.presetLua("ilha", [["quickshell:island", 0.05]], root.islandBase, root.island?.glass ?? 1, root.island?.chroma ?? 1)
            // the Mosaic theme's sidebars are solid mosaic-ui blocks over a dot field:
            // no glass (at these strengths it burnt white and fringed the edges)
            + (MosaicTheme.current === "mosaic"
                ? 'hg.layer("quickshell:sidebarLeft", { enabled = 0 })\nhg.layer("quickshell:sidebarRight", { enabled = 0 })\n'
                : root.presetLua("widgets", [["quickshell:sidebarLeft", 0.3], ["quickshell:sidebarRight", 0.3]], root.islandBase, root.widgets?.glass ?? 1, root.widgets?.chroma ?? 1))
            // the desk has glass only in macOS: Mosaic's widgets are solid blocks (mosaic-ui), and the others draw their own
            + 'hg.layer("mosaic-desk", { enabled = 0 })\n'
            + 'hg.layer("quickshell:topbar", { enabled = 0 })\n'
            + root.presetLua("doca", [["quickshell:dock", 0.12]], root.dockBase, root.dock?.glass ?? 1, root.dock?.chroma ?? 1);
    }

    // changes during startup are just the saved values being loaded: ignore them
    property bool ready: false
    Timer {
        running: true
        interval: 4000
        onTriggered: {
            root.ready = true;
            // the file on disk is from an older layout or older values: write it once
            if (file.text().trim() !== root.fileText().trim())
                applyLater.restart();
        }
    }
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
