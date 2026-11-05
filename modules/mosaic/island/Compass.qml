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

// What the island shows when it turns into the workspace compass: a small, quiet
// dome under the island's mark (the needle, in Island). Each workspace is a Mosaic tile in one
// of the four tones (same number, same tone, always) with the icon of its biggest
// window and +N when there are more; the current one is bigger and brighter. The
// tiles come out from the middle one after the other. Scrolling turns the compass
// (1 to 50, about ten in view) and switches workspace; clicking a tile goes there.
Item {
    id: root
    property bool open: false
    readonly property int maxWorkspace: 50
    readonly property int current: HyprlandData.activeWorkspace?.id ?? 1
    // where the compass points, animated: turning is smooth and a little springy
    property real offset: current
    Behavior on offset { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

    // the tiles ride an oval arc that follows the half-oval island
    readonly property real ringRadiusX: Math.max(0, width / 2 - 26)
    readonly property real ringRadiusY: Math.max(0, height - 20)
    readonly property real stepAngle: 19 // degrees between two workspaces

    // tiles pop out in a cascade once the island has opened up
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: root.open ? 620 : 140; easing.type: Easing.OutCubic } }

    readonly property var tones: [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary, ColorUtils.mix(Appearance.colors.colSecondary, Appearance.colors.colTertiary, 0.5)]
    function toneFor(id) { return root.tones[(id - 1) % 4]; }

    // the dark island surface: the soft blocks are mixed toward it
    readonly property color washBase: ColorUtils.mix("#000000", Appearance.colors.colLayer0, 0.55)
    // windows per workspace, worked out once per change (not once per block)
    readonly property var windowsByWs: {
        const map = {};
        for (const w of HyprlandData.windowList)
            (map[w.workspace.id] = map[w.workspace.id] ?? []).push(w);
        return map;
    }

    function go(id) {
        const target = Math.max(1, Math.min(root.maxWorkspace, id));
        if (target !== root.current)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${target} })`);
    }

    // the current workspace's number, under the mark (the mark is the needle, in Island)
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 27
        text: root.current
        font.family: "JetBrains Mono"
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Appearance.colors.colOnLayer0
        opacity: 0.75 * root.reveal
    }

    Repeater {
        model: 13
        delegate: Item {
            id: tile
            required property int index
            readonly property int wsId: Math.round(root.offset) - 6 + index
            readonly property real delta: wsId - root.offset
            // lower numbers on the left, higher on the right, like reading
            readonly property real angle: (90 - delta * root.stepAngle) * Math.PI / 180
            readonly property bool valid: wsId >= 1 && wsId <= root.maxWorkspace
            readonly property bool isCurrent: wsId === root.current
            readonly property var windows: root.windowsByWs[tile.wsId] ?? []
            readonly property var biggest: tile.valid ? HyprlandData.biggestWindowForWorkspace(tile.wsId) : null
            readonly property real size: isCurrent ? 26 : tile.windows.length > 0 ? 20 : 12
            readonly property color tone: root.toneFor(Math.max(1, wsId))
            // cascade: the middle tile first, then outwards
            readonly property real myReveal: Math.max(0, Math.min(1, root.reveal * 2.2 - Math.abs(delta) * 0.22))

            visible: valid && Math.abs(delta) <= 5.6 && myReveal > 0
            opacity: myReveal * Math.max(0, 1 - Math.max(0, Math.abs(delta) - 3.6) / 2)
            scale: 0.4 + 0.6 * myReveal
            width: size
            height: size
            x: root.width / 2 + Math.cos(angle) * root.ringRadiusX * (0.55 + 0.45 * myReveal) - width / 2
            y: Math.sin(angle) * root.ringRadiusY * (0.55 + 0.45 * myReveal) - height / 2
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

            // the tile: a Mosaic block in its tone (soft when away, vivid when current)
            Rectangle {
                anchors.fill: parent
                radius: Math.round(tile.size * 0.28)
                // quiet: soft tones on the dark island, only the current one a little brighter
                color: tile.isCurrent ? ColorUtils.mix(tile.tone, root.washBase, 0.7) : ColorUtils.mix(tile.tone, root.washBase, tile.windows.length > 0 ? 0.38 : 0.18)
                border.width: tile.isCurrent ? 1 : 0
                border.color: ColorUtils.mix(Appearance.colors.colOnLayer0, tile.tone, 0.5)
                Behavior on color { ColorAnimation { duration: 220 } }
            }
            IconImage {
                visible: tile.biggest !== null
                anchors.centerIn: parent
                implicitSize: Math.round(tile.size * 0.6)
                source: Quickshell.iconPath(AppSearch.guessIcon(tile.biggest?.class), "image-missing")
            }
            StyledText {
                visible: tile.biggest === null && tile.size >= 20
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
            MouseArea {
                anchors.fill: parent
                onClicked: root.go(tile.wsId)
            }
        }
    }

    // scroll turns the compass
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
