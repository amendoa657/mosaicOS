pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The workspace compass: a half circle hanging under the island, one point per
// workspace with the icon of its biggest window (+N when it has more). The
// current workspace sits at the bottom; scrolling turns the compass and moves to
// the next or previous one (1 to 50), about ten points in view at a time.
// Clicking a point goes there.
Item {
    id: root
    property bool open: false
    readonly property int maxWorkspace: 50
    readonly property int current: HyprlandData.activeWorkspace?.id ?? 1
    // where the compass points, animated: turning is smooth and a little springy
    property real offset: current
    Behavior on offset { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    readonly property real radius: 150
    readonly property real ringRadius: 112
    readonly property real stepAngle: 18 // degrees between two workspaces

    width: radius * 2
    height: radius + 8
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.85
    transformOrigin: Item.Top
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

    function go(id) {
        const target = Math.max(1, Math.min(root.maxWorkspace, id));
        if (target !== root.current)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${target} })`);
    }

    // the half disc, in the bar's surface and outline
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Appearance.colors.colLayer0
            strokeColor: Appearance.colors.colLayer0Border
            strokeWidth: 1
            startX: 0
            startY: 0
            PathArc {
                x: root.radius * 2
                y: 0
                radiusX: root.radius
                radiusY: root.radius
                useLargeArc: false
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }

    // soft tick ring
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.88)
            strokeWidth: 1
            startX: root.radius - root.ringRadius
            startY: 0
            PathArc {
                x: root.radius + root.ringRadius
                y: 0
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                direction: PathArc.Counterclockwise
            }
        }
    }

    // the current workspace's number in the middle
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 26
        text: root.current
        font.family: "Space Grotesk"
        font.pixelSize: 30
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.85
    }
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64
        text: "role para trocar"
        font.family: "JetBrains Mono"
        font.pixelSize: 9
        color: Appearance.colors.colSubtext
    }

    // the points: the current one and five on each side
    Repeater {
        model: 13
        delegate: Item {
            id: point
            required property int index
            readonly property int wsId: Math.round(root.offset) - 6 + index
            readonly property real delta: wsId - root.offset
            // lower numbers on the left, higher on the right, like reading
            readonly property real angle: (90 - delta * root.stepAngle) * Math.PI / 180
            readonly property bool valid: wsId >= 1 && wsId <= root.maxWorkspace
            readonly property bool isCurrent: wsId === root.current
            readonly property var windows: HyprlandData.windowList.filter(w => w.workspace.id === point.wsId)
            readonly property var biggest: point.valid ? HyprlandData.biggestWindowForWorkspace(point.wsId) : null
            readonly property real size: isCurrent ? 40 : point.windows.length > 0 ? 32 : 18

            visible: valid && Math.abs(delta) <= 5.5
            opacity: Math.max(0, 1 - Math.max(0, Math.abs(delta) - 3.5) / 2)
            width: size
            height: size
            x: root.radius + Math.cos(angle) * root.ringRadius - width / 2
            y: Math.sin(angle) * root.ringRadius - height / 2
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: point.isCurrent ? ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.45) : Appearance.colors.colLayer1
                border.width: point.isCurrent ? 2 : 0
                border.color: ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.75)
            }
            IconImage {
                visible: point.biggest !== null
                anchors.centerIn: parent
                implicitSize: Math.round(point.size * 0.62)
                source: Quickshell.iconPath(AppSearch.guessIcon(point.biggest?.class), "image-missing")
            }
            StyledText {
                visible: point.biggest === null
                anchors.centerIn: parent
                text: point.wsId
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                color: Appearance.colors.colSubtext
            }
            // +N when the workspace has more windows
            Rectangle {
                visible: point.windows.length > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -4
                anchors.bottomMargin: -3
                width: badge.implicitWidth + 8
                height: 14
                radius: 7
                color: ColorUtils.mix(Appearance.colors.colSecondary, Appearance.colors.colLayer1, 0.6)
                StyledText {
                    id: badge
                    anchors.centerIn: parent
                    text: `+${point.windows.length - 1}`
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer0
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.go(point.wsId)
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
