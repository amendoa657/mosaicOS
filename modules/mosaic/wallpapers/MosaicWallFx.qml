import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// The wallpaper transition (shaders/wallfx.frag), smooth, no pixels:
// - with a character (an outline map from scripts/wallfx, MosaicWalls.mapFor):
//   a line draws its outline, it fills in, and the rest spreads out of it with
//   a liquid edge and a glowing rim;
// - without one: the same liquid spread from a few seeds.
// Then the ii script applies the wallpaper for real (Matugen colours and all)
// and the overlay fades away.
// - It starts when MosaicWalls.pending gets a path (the carousel, the random
//   shortcut and the IPC all go through MosaicWalls.apply).
// - The overlay is a window per screen on the Bottom layer: over the wallpaper,
//   under the windows, and it never takes clicks.
// - It only starts once the image (and its map, if any) is loaded; if that never
//   happens within 2.5 s, the wallpaper changes anyway, without the effect.
// - The line and the rim are the new wallpaper's average colour, made vivid.
// Idea from pocket-dots (diegoMalagrida/pocket-dots, GPL-3.0).
Scope {
    id: root

    readonly property string path: MosaicWalls.pending
    readonly property bool playing: root.path !== ""
    property real progress: 0
    property real fade: 1
    property real seed: 0
    readonly property string mapSource: MosaicWalls.mapFor(root.path)

    // the burning colour: the average tone, made vivid
    readonly property color tone: {
        const hex = MosaicWalls.toneOf(root.path);
        if (!hex)
            return Appearance.colors.colPrimary;
        const c = Qt.color(hex);
        return Qt.hsla(c.hslHue, Math.max(0.7, c.hslSaturation), Math.min(0.62, Math.max(0.5, c.hslLightness)), 1);
    }

    onPathChanged: {
        if (!root.playing)
            return;
        run.stop();
        fadeOut.stop();
        root.progress = 0;
        root.fade = 1;
        root.seed = Math.random() * 100;
        guard.restart();
    }
    function imageReady() {
        if (root.playing && !run.running && root.progress === 0) {
            guard.stop();
            run.start();
        }
    }
    Timer {
        id: guard
        interval: 2500
        onTriggered: if (root.playing && root.progress === 0) root.commit()
    }
    NumberAnimation {
        id: run
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.mapSource !== "" ? 2600 : 1600 // the outline needs time to be drawn
        easing.type: root.mapSource !== "" ? Easing.Linear : Easing.InOutSine
        onFinished: root.commit()
    }
    function commit() {
        MosaicWalls.commit(root.path);
        settleGuard.restart();
    }
    // once the background shows the new picture (plus a moment to load it), the overlay fades
    Connections {
        target: Config.options.background
        function onWallpaperPathChanged() {
            if (root.playing && Config.options.background.wallpaperPath === root.path)
                settleDelay.restart();
        }
    }
    Timer { id: settleDelay; interval: 900; onTriggered: fadeOut.start() }
    Timer { id: settleGuard; interval: 8000; onTriggered: if (root.playing) fadeOut.start() }
    NumberAnimation {
        id: fadeOut
        target: root
        property: "fade"
        to: 0
        duration: 320
        onFinished: {
            settleGuard.stop();
            MosaicWalls.pending = "";
            root.progress = 0;
        }
    }

    Variants {
        model: root.playing ? Quickshell.screens : []
        delegate: PanelWindow {
            id: fxWin
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mosaicWallFx"
            WlrLayershell.layer: WlrLayer.Bottom // over the wallpaper, under the windows
            mask: Region {} // clicks go through

            Image {
                id: pic
                visible: false
                source: root.path ? "file://" + root.path : ""
                asynchronous: true
                sourceSize: Qt.size(fxWin.width, fxWin.height)
                onStatusChanged: if (status === Image.Ready && (root.mapSource === "" || mapImg.status === Image.Ready)) root.imageReady()
            }
            Image {
                id: mapImg
                visible: false
                source: root.mapSource
                asynchronous: true
                smooth: true
                onStatusChanged: if (status === Image.Ready && pic.status === Image.Ready) root.imageReady()
            }
            ShaderEffect {
                anchors.fill: parent
                visible: pic.status === Image.Ready
                fragmentShader: Qt.resolvedUrl("shaders/wallfx.frag.qsb")
                property var source: pic
                property var map: root.mapSource !== "" ? mapImg : pic
                property real hasMap: root.mapSource !== "" && mapImg.status === Image.Ready ? 1 : 0
                property vector2d size: Qt.vector2d(width, height)
                property vector2d picSize: Qt.vector2d(Math.max(1, pic.implicitWidth), Math.max(1, pic.implicitHeight))
                property real progress: root.progress
                property real seed: root.seed
                property color tone: root.tone
                opacity: root.fade
            }
        }
    }
}
