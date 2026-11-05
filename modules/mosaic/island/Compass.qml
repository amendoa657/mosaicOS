pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// What the island shows as the workspace compass: it stays a pill, just wider,
// and the workspaces pass by in a row like a carousel, to the right of the
// Mosaic mark (which turns a quarter per workspace, in Island). Each workspace
// is a Mosaic block in one of the four tones (same number, same tone, always)
// with the icon of its biggest window and +N when there are more. The current
// one sits in the middle, biggest and brightest, with its number under it; the
// others shrink and fade towards the ends. Scrolling turns the carousel (1 to
// 50) and switches workspace; clicking a block goes there.
Item {
    id: root
    property bool open: false
    property real leftReserve: 50 // the mark lives there
    readonly property int maxWorkspace: 50
    readonly property int current: HyprlandData.activeWorkspace?.id ?? 1
    // where the carousel points, on a spring: turning is smooth and a little bouncy
    property real offset: current
    Behavior on offset { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

    readonly property real step: 42 // px between two workspaces
    readonly property real centerX: leftReserve + (width - leftReserve - 12) / 2

    // blocks pop out in a cascade from the middle once the island has widened
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: root.open ? 560 : 140; easing.type: Easing.OutCubic } }

    function toneFor(id) {
        const c = Appearance.colors;
        return [c.colPrimary, c.colSecondary, c.colTertiary, ColorUtils.mix(c.colSecondary, c.colTertiary, 0.5)][(id - 1) % 4];
    }
    function go(id) {
        const target = Math.max(1, Math.min(root.maxWorkspace, id));
        if (target !== root.current)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${target} })`);
    }
    // windows per workspace, worked out once per change (not once per block)
    readonly property var windowsByWs: {
        const map = {};
        for (const w of HyprlandData.windowList)
            (map[w.workspace.id] = map[w.workspace.id] ?? []).push(w);
        return map;
    }

    Repeater {
        model: 11
        delegate: Item {
            id: tile
            required property int index
            readonly property int wsId: Math.round(root.offset) - 5 + index
            readonly property real delta: wsId - root.offset
            readonly property real dist: Math.abs(delta)
            readonly property bool valid: wsId >= 1 && wsId <= root.maxWorkspace
            readonly property bool isCurrent: wsId === root.current
            readonly property var windows: root.windowsByWs[wsId] ?? []
            readonly property var biggest: valid && windows.length > 0 ? HyprlandData.biggestWindowForWorkspace(wsId) : null
            readonly property real baseSize: isCurrent ? 36 : windows.length > 0 ? 28 : 20
            // further from the middle: a bit smaller and fainter, gone at the ends
            readonly property real falloff: Math.max(0, 1 - Math.max(0, dist - 2.6) / 2.2)
            readonly property real myReveal: Math.max(0, Math.min(1, root.reveal * 2.2 - dist * 0.24))
            readonly property color tone: root.toneFor(Math.max(1, wsId))

            visible: valid && falloff > 0 && myReveal > 0
            width: baseSize
            height: baseSize
            x: root.centerX + delta * root.step - width / 2
            y: (root.height - height) / 2 - (isCurrent ? 6 : 0) * myReveal
            opacity: myReveal * falloff
            scale: (0.5 + 0.5 * myReveal) * (1 - Math.min(dist, 4) * 0.05)
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

            // the block, in its tone: vivid when current, soft with windows, faint when empty
            Rectangle {
                anchors.fill: parent
                radius: Math.round(tile.baseSize * 0.28)
                color: tile.isCurrent ? ColorUtils.mix(tile.tone, root.washBase, 0.95)
                    : ColorUtils.mix(tile.tone, root.washBase, tile.windows.length > 0 ? 0.55 : 0.28)
                border.width: tile.isCurrent ? 2 : 0
                border.color: ColorUtils.mix(Appearance.colors.colOnLayer0, tile.tone, 0.5)
                Behavior on color { ColorAnimation { duration: 220 } }
            }
            IconImage {
                visible: tile.biggest !== null
                anchors.centerIn: parent
                implicitSize: Math.round(tile.baseSize * 0.6)
                source: Quickshell.iconPath(AppSearch.guessIcon(tile.biggest?.class), "image-missing")
            }
            StyledText {
                visible: tile.biggest === null
                anchors.centerIn: parent
                text: tile.wsId
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer0
                opacity: 0.8
            }
            // +N when the workspace has more windows
            Rectangle {
                visible: tile.windows.length > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -5
                anchors.bottomMargin: -4
                width: badge.implicitWidth + 8
                height: 14
                radius: 5
                color: ColorUtils.mix(tile.tone, Appearance.colors.colLayer0, 0.9)
                StyledText {
                    id: badge
                    anchors.centerIn: parent
                    text: `+${tile.windows.length - 1}`
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: Appearance.colors.colLayer0
                }
            }
            // the current one's number, under it
            StyledText {
                visible: tile.isCurrent && tile.biggest !== null
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 2
                text: tile.wsId
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer0
                opacity: 0.85
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.go(tile.wsId)
            }
        }
    }

    // the dark island surface, so the soft blocks are mixed toward it
    readonly property color washBase: ColorUtils.mix("#000000", Appearance.colors.colLayer0, 0.55)

    // scroll turns the carousel
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulated: 0
        onWheel: event => {
            accumulated += event.angleDelta.y;
            if (Math.abs(accumulated) < 60)
                return;
            root.go(root.current + (accumulated > 0 ? -1 : 1));
            accumulated = 0;
        }
    }
}
