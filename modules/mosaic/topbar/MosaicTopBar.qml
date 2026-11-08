pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mosaic.island

// The top band: a strip reserved at the top of every screen (windows start
// under it), with the workspaces on the left and a few states on the right.
// The middle belongs to the island, which sits inside the band at rest.
// - Reserved: exclusiveZone = 40 px (6 above the island + its 30 + 4). It has no
//   background; the mask only takes clicks on the two groups.
// - Workspaces: one dot per workspace of this screen (Hyprland only keeps the
//   ones with windows, plus the active one). The active one is a pill that
//   travels like a worm: its two ends are two springs, and the end in front is
//   quicker than the one behind, so the pill stretches on the way and gathers
//   itself on arrival. Click goes there, the wheel walks through them.
// - States: only what is worth a glance, each icon showing up only while it is
//   true: recording, caffeine, updates, do not disturb (with the count),
//   Bluetooth connected, offline, muted.
// - Glyphs carry a thin dark outline, so they read over any wallpaper.
// - Hidden while a window is in real full screen on that screen.
// Idea from pocket-dots' top bar (diegoMalagrida/pocket-dots, GPL-3.0).
Scope {
    id: root
    readonly property int band: 40

    // recording: the recorder is running (gpu-screen-recorder or wf-recorder)
    property bool recording: false
    Process {
        id: recCheck
        command: ["sh", "-c", "pgrep -x 'gpu-screen-reco|wf-recorder' >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.recording = this.text.trim() === "1" }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: recCheck.running = true }

    readonly property bool offline: !Network.ethernet && Network.wifiStatus !== "connected"
    readonly property bool muted: Audio.sink?.audio?.muted ?? false

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: root.band
            exclusiveZone: root.band
            color: "transparent"
            WlrLayershell.namespace: "quickshell:topbar"
            WlrLayershell.layer: WlrLayer.Top
            mask: Region {
                Region { item: left }
                Region { item: right }
            }

            readonly property var hlMonitor: Hyprland.monitors.values.find(m => m.name === bar.screen.name) ?? null
            readonly property int activeId: bar.hlMonitor?.activeWorkspace?.id ?? 1
            readonly property bool fullscreenHere: HyprlandData.windowList.some(w => w.workspace?.id === bar.activeId && w.fullscreen >= 2)
            // this screen's workspaces, the active one always among them
            readonly property var workspaces: {
                const ids = Hyprland.workspaces.values.filter(ws => ws.id > 0 && ws.monitor?.name === bar.screen.name).map(ws => ws.id);
                if (!ids.includes(bar.activeId))
                    ids.push(bar.activeId);
                return ids.sort((a, b) => a - b);
            }

            Item {
                anchors.fill: parent
                opacity: bar.fullscreenHere ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 180 } }

                // ---------- left: the workspaces ----------
                Item {
                    id: left
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1
                    width: dots.width + 16
                    height: 26

                    readonly property real dot: 7
                    readonly property real gap: 9
                    readonly property real pillW: 20
                    readonly property int activeIndex: Math.max(0, bar.workspaces.indexOf(bar.activeId))
                    function xOf(i) { return 8 + i * (left.dot + left.gap); }

                    // where the pill wants to be, and which way it is going
                    readonly property real wantL: left.xOf(left.activeIndex) - (left.pillW - left.dot) / 2 + 2
                    readonly property real wantR: left.wantL + left.pillW
                    property bool goingRight: true
                    onWantLChanged: left.goingRight = left.wantL > leadL.value
                    // the worm: the end in front is quick, the one behind holds on and lets go
                    MosaicSpring {
                        id: leadL
                        target: left.wantL
                        response: left.goingRight ? 0.42 : 0.2
                        damping: 0.78
                        Component.onCompleted: settle(target)
                    }
                    MosaicSpring {
                        id: leadR
                        target: left.wantR
                        response: left.goingRight ? 0.2 : 0.42
                        damping: 0.78
                        Component.onCompleted: settle(target)
                    }

                    Row {
                        id: dots
                        x: 8 + left.dot / 2 - left.dot / 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: left.gap
                        Repeater {
                            model: bar.workspaces
                            delegate: Rectangle {
                                id: wsDot
                                required property int modelData
                                width: left.dot
                                height: left.dot
                                radius: MosaicTheme.brutal ? MosaicTheme.r(2) : width / 2
                                color: MosaicTheme.brutal ? MosaicTheme.slab : Qt.rgba(1, 1, 1, dotArea.containsMouse ? 0.95 : 0.7)
                                border.width: MosaicTheme.brutal ? 1.5 : 0.5
                                border.color: MosaicTheme.brutal ? MosaicTheme.ink : Qt.rgba(0, 0, 0, 0.45)
                                MouseArea {
                                    id: dotArea
                                    anchors.centerIn: parent
                                    width: left.dot + left.gap
                                    height: 26
                                    hoverEnabled: true
                                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsDot.modelData} })`)
                                }
                            }
                        }
                    }

                    // the pill: its thickness thins a little while it is stretched
                    readonly property real stretch: Math.max(0, (leadR.value - leadL.value) - left.pillW)
                    Rectangle {
                        // brutal themes: a hard shadow under the pill
                        visible: MosaicTheme.brutal
                        x: pill.x + 2
                        y: pill.y + 2
                        width: pill.width
                        height: pill.height
                        radius: pill.radius
                        color: MosaicTheme.shadowColor
                    }
                    Rectangle {
                        id: pill
                        x: leadL.value
                        width: Math.max(left.dot, leadR.value - leadL.value)
                        height: Math.max(4, left.dot + 1 - Math.min(3, left.stretch * 0.06))
                        anchors.verticalCenter: parent.verticalCenter
                        radius: MosaicTheme.brutal ? MosaicTheme.r(3) : height / 2
                        color: Appearance.colors.colPrimary
                        border.width: MosaicTheme.brutal ? 1.5 : 0.5
                        border.color: MosaicTheme.brutal ? MosaicTheme.ink : Qt.rgba(0, 0, 0, 0.35)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            const i = left.activeIndex + (wheel.angleDelta.y < 0 ? 1 : -1);
                            if (i >= 0 && i < bar.workspaces.length)
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${bar.workspaces[i]} })`);
                        }
                    }
                }

                // ---------- right: the states ----------
                Row {
                    id: right
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1
                    spacing: 4
                    layoutDirection: Qt.RightToLeft

                    StateIcon {
                        shown: root.muted
                        icon: "volume_off"
                        onClicked: Audio.toggleMute()
                    }
                    StateIcon {
                        shown: root.offline
                        icon: "wifi_off"
                        tint: Appearance.m3colors.m3error
                    }
                    StateIcon {
                        shown: BluetoothStatus.connected
                        icon: "bluetooth_connected"
                    }
                    StateIcon {
                        shown: Notifications.silent
                        icon: "notifications_off"
                        label: Notifications.list.length > 0 ? String(Notifications.list.length) : ""
                        onClicked: Notifications.silent = false
                    }
                    StateIcon {
                        shown: Updates.available && Updates.count > 0
                        icon: "cloud_download"
                        tint: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer0
                    }
                    StateIcon {
                        shown: Idle.inhibit
                        icon: "coffee"
                        onClicked: Idle.inhibit = false
                    }
                    // recording: it winks once every 2 s instead of pulsing all the time
                    StateIcon {
                        id: recIcon
                        shown: root.recording
                        icon: "fiber_manual_record"
                        tint: "#ff5a5f"
                        fill: 1
                        SequentialAnimation on opacity {
                            running: root.recording
                            loops: Animation.Infinite
                            PauseAnimation { duration: 1700 }
                            NumberAnimation { to: 0.25; duration: 150 }
                            NumberAnimation { to: 1; duration: 150 }
                        }
                    }
                }
            }
        }
    }

    // a state on the right: an icon (and maybe a number), present only while `shown`
    component StateIcon: Item {
        id: st
        property bool shown: false
        property string icon: ""
        property string label: ""
        property color tint: MosaicTheme.brutal ? MosaicTheme.ink : "white"
        property real fill: 0
        signal clicked()
        visible: width > 0.5
        width: st.shown ? row.implicitWidth + 12 : 0
        height: 26
        clip: true
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent
            radius: MosaicTheme.brutal ? MosaicTheme.r(4) : 8
            color: MosaicTheme.brutal ? MosaicTheme.slab : Qt.rgba(1, 1, 1, area.containsMouse ? 0.16 : 0)
            border.width: MosaicTheme.brutal ? 1.5 : 0
            border.color: MosaicTheme.ink
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 3
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: st.icon
                iconSize: 17
                fill: st.fill
                color: st.tint
                style: Text.Outline
                styleColor: MosaicTheme.brutal ? "transparent" : Qt.rgba(0, 0, 0, 0.5)
            }
            StyledText {
                visible: st.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: st.label
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: st.tint
                style: Text.Outline
                styleColor: MosaicTheme.brutal ? "transparent" : Qt.rgba(0, 0, 0, 0.5)
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: st.clicked()
        }
    }
}
