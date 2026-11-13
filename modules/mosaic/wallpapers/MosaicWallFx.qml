import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// The wallpaper transition. Two of them, by theme:
// - the Mosaic theme: mosaic-ui's pixel wave (shaders/pixelfx.frag), below;
// - the other themes: the liquid spread (shaders/wallfx.frag), with the
//   character's outline when it has a map (scripts/wallfx, MosaicWalls.mapFor),
//   from pocket-dots (diegoMalagrida/pocket-dots, GPL-3.0).
// The pixel wave: a wave leaves a corner (or the bottom middle); each cell becomes a square in
// one of the new wallpaper's four tones, and the square shrinks away over the
// new picture. The desk's widgets join in: when the wave reaches one, its card
// is covered by the same squares and revealed again (desk/desktop/Widget.qml,
// through MosaicWalls.waveStarted). Then the ii script applies the wallpaper
// for real (Matugen colours and all) and the overlay fades away.
// - It starts when MosaicWalls.pending gets a path (the carousel, the random
//   shortcut and the IPC all go through MosaicWalls.apply).
// - The overlay is a window per screen on the Background layer, made after the
//   wallpaper's, so it sits over the wallpaper and under the desk's widgets
//   (on Bottom it covered them until it faded). It never takes clicks.
// - It only starts once the image is loaded; if that never happens within
//   2.5 s, the wallpaper changes anyway, without the effect.
Scope {
    id: root

    readonly property string path: MosaicWalls.pending
    readonly property bool playing: root.path !== ""
    property real progress: 0
    property real fade: 1
    property real seed: 0
    // which transition: decided when it starts, so a theme change mid-way does not swap it
    property bool pixels: true
    readonly property string mapSource: root.pixels ? "" : MosaicWalls.mapFor(root.path)

    // the four tones: the average colour made vivid, plus three neighbours of it
    readonly property var tones: {
        const hex = MosaicWalls.toneOf(root.path);
        const c = hex ? Qt.color(hex) : Appearance.colors.colPrimary;
        const h = c.hslHue < 0 ? 0 : c.hslHue;
        const s = Math.max(0.6, c.hslSaturation);
        const wrap = x => (x + 1) % 1;
        return [
            Qt.hsla(h, s, 0.58, 1),
            Qt.hsla(wrap(h + 0.07), s, 0.70, 1),
            Qt.hsla(wrap(h - 0.07), s * 0.9, 0.46, 1),
            Qt.hsla(h, s * 0.55, 0.80, 1)
        ];
    }
    // the bottom middle, or one of the four corners
    readonly property var origins: [Qt.vector2d(0.5, 1), Qt.vector2d(0, 0), Qt.vector2d(1, 0), Qt.vector2d(0, 1), Qt.vector2d(1, 1)]

    onPathChanged: {
        if (!root.playing)
            return;
        run.stop();
        fadeOut.stop();
        root.progress = 0;
        root.fade = 1;
        root.seed = Math.random() * 100;
        root.pixels = MosaicTheme.current === "mosaic";
        MosaicWalls.waveOrigin = root.origins[Math.floor(Math.random() * root.origins.length)];
        guard.restart();
    }
    function imageReady() {
        if (root.playing && !run.running && root.progress === 0) {
            guard.stop();
            MosaicWalls.waveTones = root.tones;
            run.start();
            if (root.pixels)
                MosaicWalls.waveStarted(); // the desk's widgets join in
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
        // the cells bring their own easing; the outline needs time to be drawn
        duration: root.pixels ? MosaicWalls.waveDuration : root.mapSource !== "" ? 2600 : 1600
        easing.type: root.pixels || root.mapSource !== "" ? Easing.Linear : Easing.InOutSine
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
            WlrLayershell.layer: WlrLayer.Background // over the wallpaper, under the widgets
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
            // the Mosaic theme: the pixel wave
            ShaderEffect {
                anchors.fill: parent
                visible: root.pixels && pic.status === Image.Ready
                fragmentShader: Qt.resolvedUrl("shaders/pixelfx.frag.qsb")
                property var source: pic
                property vector2d size: Qt.vector2d(width, height)
                property vector2d picSize: Qt.vector2d(Math.max(1, pic.implicitWidth), Math.max(1, pic.implicitHeight))
                property vector2d origin: MosaicWalls.waveOrigin
                property real progress: root.progress
                property real cell: 24
                property color tone0: root.tones[0]
                property color tone1: root.tones[1]
                property color tone2: root.tones[2]
                property color tone3: root.tones[3]
                opacity: root.fade
            }
            // the other themes: the liquid spread, with the outline when there is a map
            ShaderEffect {
                anchors.fill: parent
                visible: !root.pixels && pic.status === Image.Ready
                fragmentShader: Qt.resolvedUrl("shaders/wallfx.frag.qsb")
                property var source: pic
                property var map: root.mapSource !== "" ? mapImg : pic
                property real hasMap: root.mapSource !== "" && mapImg.status === Image.Ready ? 1 : 0
                property vector2d size: Qt.vector2d(width, height)
                property vector2d picSize: Qt.vector2d(Math.max(1, pic.implicitWidth), Math.max(1, pic.implicitHeight))
                property real progress: root.progress
                property real seed: root.seed
                property color tone: root.tones[0]
                opacity: root.fade
            }
        }
    }
}
