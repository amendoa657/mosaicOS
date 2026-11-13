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
import qs.desk.services as Desk
import qs.desk.components as DeskUi

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
    readonly property int band: 30
    readonly property int pillH: 26

    // recording: the recorder is running (the one check is MosaicRecording)
    readonly property bool recording: MosaicRecording.recording

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
            margins.top: 0
            implicitHeight: root.band
            exclusiveZone: root.band
            color: "transparent"
            WlrLayershell.namespace: "quickshell:topbar"
            WlrLayershell.layer: WlrLayer.Top
            mask: Region {
                Region { item: leftPill }
                Region { item: rightPill }
                Region { item: MosaicTheme.mac ? appTitle : null }
                Region { item: MosaicTheme.mac ? macMark : null }
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

                // ---------- macOS theme: the menu bar ----------
                // one translucent bar across the screen (the theme's liquid glass is
                // on this layer), the focused app's name in bold on the left, the date
                // and time on the right; the island in the middle is the notch
                // from edge to edge, a near-solid dark grey (macOS's dark menu bar), a
                // dark hairline under it. The
                // island in the middle is the notch: black, flush with the edge, as
                // tall as the bar, and it shows the time, so the bar shows the date
                Rectangle {
                    visible: MosaicTheme.mac
                    anchors.fill: parent
                    // a dark veil over the liquid glass (a thin lens, little blur: the
                    // heavy frost read as a smudge), light enough for the bend to show
                    color: Qt.rgba(0.10, 0.10, 0.11, 0.42)
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                }
                // the Mosaic mark where the Apple menu goes: it opens the start menu
                Grid {
                    id: macMark
                    visible: MosaicTheme.mac
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    spacing: 1.5
                    Repeater {
                        model: [Appearance.m3colors.m3primary, Appearance.m3colors.m3secondary, Appearance.m3colors.m3tertiary, "#f5f5f7"]
                        Rectangle { required property var modelData; width: 6; height: 6; radius: 1.5; color: modelData }
                    }
                    TapHandler { onTapped: GlobalStates.searchOpen = !GlobalStates.searchOpen }
                }
                Text {
                    id: appTitle
                    visible: MosaicTheme.mac
                    x: macMark.x + macMark.width + 16
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property string appId: ToplevelManager.activeToplevel?.appId ?? ""
                    readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
                    text: entry?.name ?? (appId !== "" ? appId.split(".").pop().replace(/^./, c => c.toUpperCase()) : "Mesa")
                    font.family: MosaicTheme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "white"
                }

                // ---------- left: the workspaces ----------
                Pill {
                    id: leftPill
                    x: MosaicTheme.mac ? appTitle.x + appTitle.implicitWidth + 10 : 6
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
                    anchors.rightMargin: 5
                    width: stateRow.width > 0 ? stateRow.width + 8 : 0
                    visible: width > 1
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Row {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 0
                        layoutDirection: Qt.RightToLeft

                        // macOS theme, right to left as on the Mac: the date (the time is
                        // in the notch), the control centre (the right sidebar), search
                        // (the start menu), the sound and the network
                        Text {
                            visible: MosaicTheme.mac
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 10
                            rightPadding: 8
                            text: barClock.date.toLocaleString(Qt.locale(), "ddd d 'de' MMM").replace(".", "")
                            font.family: MosaicTheme.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "white"
                            SystemClock { id: barClock; precision: SystemClock.Minutes }
                        }
                        MacIcon { icon: "toggle_on"; onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen }
                        MacIcon { icon: "search"; onClicked: GlobalStates.searchOpen = !GlobalStates.searchOpen }
                        MacIcon { icon: root.muted ? "volume_off" : "volume_up"; onClicked: Audio.toggleMute() }
                        MacIcon { icon: Network.materialSymbol; onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen }

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
                        // Claude Code: a ring for the 5-hour block (the plan's use when the
                        // account answers, else the time gone), Claude's mark inside and the
                        // block's tokens; a click shows the details on the island
                        Item {
                            id: claudeRing
                            readonly property bool shown: Desk.ClaudeService.available && Desk.ClaudeService.remaining > 0
                            visible: width > 0.5
                            width: shown ? claudeRow.implicitWidth + 12 : 0
                            height: root.pillH
                            clip: true
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Component.onCompleted: Desk.ClaudeService.subscribe()
                            Component.onDestruction: Desk.ClaudeService.release()
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 2
                                height: parent.height - 6
                                radius: height / 2
                                color: ColorUtils.transparentize(root.fg, claudeArea.containsMouse ? 0.85 : 1)
                            }
                            Row {
                                id: claudeRow
                                anchors.centerIn: parent
                                spacing: 4
                                DeskUi.RingIndicator {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    thickness: 2
                                    progress: Desk.ClaudeService.gauge
                                    trackColor: ColorUtils.transparentize(root.fg, 0.75)
                                    fillColor: Desk.ClaudeService.gauge >= 0.85 ? Appearance.m3colors.m3error : "#d97757"
                                    DeskUi.ClaudeMark {
                                        anchors.centerIn: parent
                                        width: 9
                                        height: 9
                                        color: root.fg
                                    }
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Desk.ClaudeService.measured ? Desk.ClaudeService.percent(Desk.ClaudeService.gauge) : Desk.ClaudeService.compact(Desk.ClaudeService.blockTokens)
                                    font.family: MosaicTheme.fontUi
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: root.fg
                                }
                            }
                            MouseArea {
                                id: claudeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    const c = Desk.ClaudeService;
                                    const left = Math.ceil(c.remaining / 60000);
                                    Quickshell.execDetached(["qs", "-c", "mosaic", "ipc", "call", "island", "claude", "usage", "uso",
                                        `${c.compact(c.blockTokens)} tokens · ${c.messages(c.blockMessages)} · renova em ${Math.floor(left / 60)} h ${left % 60} min`]);
                                }
                            }
                        }
                        StateIcon {
                            shown: Idle.inhibit
                            icon: "coffee"
                            onClicked: Idle.inhibit = false
                        }
                        // the study mode: until when (a click opens its tab)
                        StateIcon {
                            shown: MosaicEstudo.active
                            icon: MosaicEstudo.release ? "lock_open" : "school"
                            label: MosaicEstudo.clock(MosaicEstudo.until)
                            fill: 1
                            onClicked: Quickshell.execDetached(["qs", "-c", "mosaic", "ipc", "call", "mosaicSettings", "estudo"])
                        }
                        // recording: it winks once every 2 s instead of pulsing all the time
                        // (a timer dims it for a moment; a looping animation, pause included,
                        // drew the band on every frame for the whole recording)
                        StateIcon {
                            id: recIcon
                            shown: root.recording
                            icon: "radio_button_checked"
                            tint: "#ff5a5f"
                            fill: 1
                            property bool wink: false
                            opacity: wink ? 0.25 : 1
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Timer { running: root.recording; repeat: true; interval: 2000; onTriggered: { recIcon.wink = true; unwink.restart(); } }
                            Timer { id: unwink; interval: 160; onTriggered: recIcon.wink = false }
                        }
                    }
                }
            }
        }
    }

    // a dark pill in the island's look (brutal: a slab with an outline and a hard shadow)
    component Pill: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        // centred on the island (6 below the edge, 30 tall: centre at 21); macOS: on the bar's own middle
        anchors.verticalCenterOffset: MosaicTheme.mac ? 0 : 2
        height: root.pillH
        radius: MosaicTheme.brutal ? MosaicTheme.r(8) : height / 2
        // macOS: no pill, it is all one menu bar
        color: MosaicTheme.mac ? "transparent" : root.pillAlphaColor
        border.width: MosaicTheme.mac ? 0 : MosaicTheme.brutal ? MosaicTheme.border : 1
        border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
        HardShadow {}
        Grain { radius: parent.radius; amount: MosaicTheme.grainIsland }
    }

    // a state on the right: an icon (and maybe a number), present only while `shown`
    // macOS theme: a menu-bar icon, white, a soft round pad under the pointer
    component MacIcon: Item {
        id: mi
        property string icon: ""
        signal clicked()
        visible: MosaicTheme.mac
        width: 30
        height: root.pillH
        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 22
            radius: 6
            color: Qt.rgba(1, 1, 1, miArea.containsMouse ? 0.16 : 0)
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: mi.icon
            iconSize: 17
            fill: 1
            color: "white"
        }
        MouseArea { id: miArea; anchors.fill: parent; hoverEnabled: true; onClicked: mi.clicked() }
    }

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
