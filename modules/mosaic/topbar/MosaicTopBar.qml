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
import qs.modules.common.functions
import qs.modules.mosaic.island

// The top band: a strip reserved at the top of every screen (windows start
// under it), with the workspaces on the left and a few states on the right.
// The middle belongs to the island, which sits inside the band at rest.
// - Reserved: exclusiveZone = 34 px. The island ends at 36 (6 above it + its 30)
//   and Hyprland adds a 5 px gap, so windows start just under the island.
//   It has no background of its own; the mask only takes clicks on the groups.
// - Both groups are dark pills in the island's look (the Ilha tab's darkness
//   and transparency), so they read over any wallpaper and match the island.
// - Workspaces, on demand: 1 to 4 always, plus any other one that has windows.
//   A workspace with windows shows the icon of the app used last there; an
//   empty one, a small dot. The active one sits on a highlight that travels
//   like a worm: its two ends are two springs, the end in front quicker than
//   the one behind, so it stretches on the way and gathers itself on arrival.
//   Click goes there, the wheel walks through them.
// - States: only what is worth a glance, each icon showing up only while it is
//   true: recording, caffeine, updates, do not disturb (with the count),
//   Bluetooth connected, offline, muted. With none, the right pill is gone.
// - Hidden while a window is in real full screen on that screen.
// Idea from pocket-dots' top bar (diegoMalagrida/pocket-dots, GPL-3.0).
Scope {
    id: root
    readonly property int band: 34
    readonly property int pillH: 26

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

    // the pills' surface: the island's
    readonly property color pillColor: ColorUtils.mix("#000000", Appearance.colors.colLayer0, Config.options.mosaicIsland.darkness)
    readonly property color pillAlphaColor: MosaicTheme.brutal ? MosaicTheme.slab
        : Qt.rgba(root.pillColor.r, root.pillColor.g, root.pillColor.b, Math.max(0.55, Config.options.mosaicIsland.opacity))
    readonly property color fg: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colOnLayer0

    // windows by workspace, newest first (focusHistoryID: 0 = the last one used)
    readonly property var windowsByWs: {
        const by = {};
        for (const w of HyprlandData.windowList) {
            const id = w.workspace?.id ?? 0;
            if (id > 0)
                (by[id] = by[id] ?? []).push(w);
        }
        for (const id in by)
            by[id].sort((a, b) => a.focusHistoryID - b.focusHistoryID);
        return by;
    }
    function iconFor(cls) { return Quickshell.iconPath(AppSearch.guessIcon(cls), "application-x-executable"); }

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
                Region { item: leftPill }
                Region { item: rightPill }
            }

            readonly property var hlMonitor: Hyprland.monitors.values.find(m => m.name === bar.screen.name) ?? null
            readonly property int activeId: bar.hlMonitor?.activeWorkspace?.id ?? 1
            readonly property bool fullscreenHere: HyprlandData.windowList.some(w => w.workspace?.id === bar.activeId && w.fullscreen >= 2)
            // on demand: 1-4, any other with windows, and the active one
            readonly property var workspaces: {
                const ids = [1, 2, 3, 4];
                for (const id of Object.keys(root.windowsByWs).map(Number))
                    if (!ids.includes(id))
                        ids.push(id);
                if (bar.activeId > 0 && !ids.includes(bar.activeId))
                    ids.push(bar.activeId);
                return ids.sort((a, b) => a - b);
            }

            Item {
                anchors.fill: parent
                opacity: bar.fullscreenHere ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 180 } }

                // ---------- left: the workspaces ----------
                Pill {
                    id: leftPill
                    x: 8
                    width: wsRow.width + 8
                    readonly property real slot: 22
                    readonly property real gap: 2
                    readonly property int activeIndex: Math.max(0, bar.workspaces.indexOf(bar.activeId))
                    function xOf(i) { return 4 + i * (leftPill.slot + leftPill.gap); }

                    // the highlight's two ends, and which way it is going
                    readonly property real wantL: leftPill.xOf(leftPill.activeIndex)
                    property bool goingRight: true
                    onWantLChanged: leftPill.goingRight = leftPill.wantL > endL.value
                    MosaicSpring {
                        id: endL
                        target: leftPill.wantL
                        response: leftPill.goingRight ? 0.42 : 0.2
                        damping: 0.78
                        Component.onCompleted: settle(target)
                    }
                    MosaicSpring {
                        id: endR
                        target: leftPill.wantL + leftPill.slot
                        response: leftPill.goingRight ? 0.2 : 0.42
                        damping: 0.78
                        Component.onCompleted: settle(target)
                    }
                    // the highlight under the active workspace
                    Rectangle {
                        x: endL.value
                        width: Math.max(leftPill.slot * 0.6, endR.value - endL.value)
                        height: leftPill.slot
                        anchors.verticalCenter: parent.verticalCenter
                        radius: MosaicTheme.brutal ? MosaicTheme.r(5) : height / 2
                        color: MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.55)
                        border.width: MosaicTheme.brutal ? 1.5 : 0
                        border.color: MosaicTheme.ink
                    }

                    Row {
                        id: wsRow
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: leftPill.gap
                        Repeater {
                            model: bar.workspaces
                            delegate: Item {
                                id: ws
                                required property int modelData
                                readonly property var wins: root.windowsByWs[ws.modelData] ?? []
                                readonly property bool active: ws.modelData === bar.activeId
                                width: leftPill.slot
                                height: leftPill.slot
                                // a new workspace grows in
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                                // empty: a dot
                                Rectangle {
                                    visible: ws.wins.length === 0
                                    anchors.centerIn: parent
                                    width: ws.active ? 7 : 5
                                    height: width
                                    radius: MosaicTheme.brutal ? MosaicTheme.r(1.5) : width / 2
                                    color: root.fg
                                    opacity: ws.active ? 1 : 0.55
                                }
                                // with windows: the app used last there
                                Image {
                                    visible: ws.wins.length > 0
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    sourceSize: Qt.size(32, 32)
                                    smooth: true
                                    mipmap: true
                                    source: ws.wins.length > 0 ? root.iconFor(ws.wins[0].class) : ""
                                    opacity: ws.active || wsArea.containsMouse ? 1 : 0.8
                                }
                                // more than one window: a tiny count in the corner
                                StyledText {
                                    visible: ws.wins.length > 1
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 1
                                    text: String(ws.wins.length)
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: root.fg
                                }
                                MouseArea {
                                    id: wsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.modelData} })`)
                                }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            const i = leftPill.activeIndex + (wheel.angleDelta.y < 0 ? 1 : -1);
                            if (i >= 0 && i < bar.workspaces.length)
                                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${bar.workspaces[i]} })`);
                        }
                    }
                }

                // ---------- right: the states ----------
                Pill {
                    id: rightPill
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    width: stateRow.width > 0 ? stateRow.width + 8 : 0
                    visible: width > 1
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Row {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 0
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
                            icon: "deployed_code_update"
                            tint: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error : root.fg
                        }
                        StateIcon {
                            shown: Idle.inhibit
                            icon: "coffee"
                            onClicked: Idle.inhibit = false
                        }
                        // recording: it winks once every 2 s instead of pulsing all the time
                        StateIcon {
                            shown: root.recording
                            icon: "radio_button_checked"
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
    }

    // a dark pill in the island's look (brutal: a slab with an outline and a hard shadow)
    component Pill: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 4 // centred on the island (6 below the edge, 30 tall: centre at 21)
        height: root.pillH
        radius: MosaicTheme.brutal ? MosaicTheme.r(8) : height / 2
        color: root.pillAlphaColor
        border.width: MosaicTheme.brutal ? MosaicTheme.border : 1
        border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
        HardShadow {}
        Grain { radius: parent.radius; amount: MosaicTheme.grainIsland }
    }

    // a state on the right: an icon (and maybe a number), present only while `shown`
    component StateIcon: Item {
        id: st
        property bool shown: false
        property string icon: ""
        property string label: ""
        property color tint: root.fg
        property real fill: 0
        signal clicked()
        visible: width > 0.5
        width: st.shown ? row.implicitWidth + 12 : 0
        height: root.pillH
        clip: true
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 6
            radius: height / 2
            color: ColorUtils.transparentize(root.fg, area.containsMouse ? 0.85 : 1)
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 3
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: st.icon
                iconSize: 16
                fill: st.fill
                color: st.tint
            }
            StyledText {
                visible: st.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: st.label
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: st.tint
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
