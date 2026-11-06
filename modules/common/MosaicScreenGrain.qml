pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Film grain on every app (Apps tab: Config.options.mosaicApps), terminal included.
// The shell can't draw over other apps' windows, so Hyprland does it: a screen
// shader (decoration.screen_shader) runs on the whole picture of every monitor
// and adds the same per-pixel noise as the shell's Grain.
// - Only themes with grain (retro, like Horizonte) have any:
//   amount = the theme's grain × the Apps tab's slider.
// - The shader has no inputs Hyprland lets us set, so the amount is written into
//   the shader text. Each amount gets its own file name: Hyprland only reads a
//   shader again when the path changes.
// - While it is on, the shell turns its own grain off (MosaicTheme.shellGrain),
//   since the screen shader already covers the shell: no double grain.
// - With a window in real full screen (fullscreen 2: games, video) on a visible
//   workspace, it goes off if `fullscreenOff`: a screen shader stops the GPU from
//   handing a game's frames straight to the monitor (direct scanout).
// - Any config reload (glass sliders, theme, wallpaper) clears the shader, so it
//   is set again on Hyprland's "configreloaded" event.
Singleton {
    id: root

    readonly property var apps: Config.options?.mosaicApps
    readonly property bool fullscreenVisible: HyprlandData.windowList.some(w => w.fullscreen >= 2
        && HyprlandData.monitors.some(m => m.activeWorkspace?.id === w.workspace?.id))
    // what the apps get right now (0 = shader off)
    readonly property real amount: (root.apps?.fullscreenOff ?? true) && root.fullscreenVisible ? 0
        : MosaicTheme.grain * (root.apps?.grain ?? 1)
    // the grain the user asked for, ignoring full screen: the shell steps aside
    // for it even while a game hides it for a moment
    readonly property bool wanted: MosaicTheme.grain * (root.apps?.grain ?? 1) > 0.001
    readonly property string dir: Quickshell.env("HOME") + "/.cache/mosaic-os"
    readonly property string path: `${root.dir}/grain-${Math.round(root.amount * 10000)}.frag`

    function shaderText(a) {
        return `#version 300 es
// written by Mosaic OS (Apps tab): film grain on the whole screen
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
void main() {
    vec4 c = texture(tex, v_texcoord);
    c.rgb += (hash(floor(gl_FragCoord.xy)) - 0.5) * ${a.toFixed(4)};
    fragColor = c;
}
`;
    }

    function setShader(p) {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { screen_shader = "${p}" } })`]);
    }
    function apply() {
        if (root.amount <= 0.001) {
            root.setShader("");
            return;
        }
        // already written (a config reload cleared it): just set it again
        if (root.written === root.path) {
            root.setShader(root.path);
            return;
        }
        file.path = root.path;
        file.setText(root.shaderText(root.amount));
    }
    property string written: "" // the shader file already on disk
    FileView {
        id: file
        printErrors: false
        onSaved: {
            root.written = path;
            root.setShader(path);
            // the files of older amounts go (not this one)
            const name = path.substring(path.lastIndexOf("/") + 1);
            Quickshell.execDetached(["find", root.dir, "-maxdepth", "1", "-name", "grain-*.frag", "!", "-name", name, "-delete"]);
        }
    }

    // a slider drag only writes once it stops for a moment
    onAmountChanged: later.restart()
    Timer {
        id: later
        interval: 250
        onTriggered: root.apply()
    }
    Component.onCompleted: later.restart()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                later.restart();
        }
    }
}
