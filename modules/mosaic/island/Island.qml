pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar

// Mosaic OS island: a notch on the top edge with the living Mosaic mark, dressed
// like the bottom bar (its surface and outline) with blocks in the Matugen tones
// inside, the way the bar groups its things.
// - Notifications show up whole inside it; the mark jumps.
// - Click anywhere opens the panel (stays until a click outside or Esc).
//   Pushing the mouse to the top edge opens it too, and then it closes when the
//   mouse leaves.
// - Panel: time + weather, music under them, quick tools (they left the bottom
//   bar) and the performance mosaic (CPU, RAM, GPU, swap filling up).
Scope {
    id: root

    // One panel at a time: the screen it is open on, and whether the mouse opened it
    property string openScreen: ""
    property bool openedByHover: false
    readonly property bool hasNotifs: Notifications.popupList.length > 0
    // a player with something loaded (browsers keep idle players around)
    readonly property bool hasPlayer: (MprisController.activePlayer?.trackTitle ?? "") !== ""
    readonly property bool playing: MprisController.isPlaying

    signal jumpRequested()

    Connections {
        target: Notifications
        function onNotify(notification) {
            if (!Notifications.silent)
                root.jumpRequested();
        }
    }

    // qs -c mosaic ipc call island <toggle|close|poke>
    IpcHandler {
        target: "island"
        function toggle(): void {
            const focused = Hyprland.focusedMonitor?.name ?? "";
            root.openedByHover = false;
            root.openScreen = root.openScreen === focused ? "" : focused;
        }
        function close(): void { root.openScreen = ""; }
        function poke(): void { root.jumpRequested(); }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:island"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            color: "transparent"
            implicitWidth: 560
            implicitHeight: 660
            // The notch, plus a thin strip on the top edge that opens it on hover
            mask: Region {
                item: notch
                Region {
                    item: edgeSensor
                }
            }

            readonly property bool panelOpen: root.openScreen === win.screen.name
            readonly property bool pinned: win.panelOpen && !root.openedByHover
            function setOpen(open, byHover) {
                root.openedByHover = open && (byHover ?? false);
                root.openScreen = open ? win.screen.name : (root.openScreen === win.screen.name ? "" : root.openScreen);
            }

            // Opened by click: keyboard (Esc) and click-outside close it, like the ii sidebars
            WlrLayershell.keyboardFocus: win.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            HyprlandFocusGrab {
                active: win.pinned && !ledPopup.open
                windows: [win]
                onCleared: win.setOpen(false)
            }

            // ---------- hover: the top edge opens it, leaving closes it ----------
            Item {
                id: edgeSensor
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360
                height: 2
                HoverHandler {
                    onHoveredChanged: if (hovered && !win.panelOpen && !root.hasNotifs) win.setOpen(true, true)
                }
            }
            Timer {
                id: leaveTimer
                interval: 350
                onTriggered: if (root.openedByHover && win.panelOpen && !notchHover.hovered && !ledPopup.open) win.setOpen(false)
            }

            Item {
                id: notch
                // what is open: notifications win over the panel
                readonly property string mode: root.hasNotifs ? "notifs" : win.panelOpen ? "panel" : ""
                readonly property real restWidth: 64
                readonly property real restHeight: 32
                readonly property real radius: Appearance.rounding.windowRounding

                anchors.horizontalCenter: parent.horizontalCenter
                width: mode === "" ? restWidth : 460
                height: mode === "" ? restHeight : Math.min(Math.round(content.implicitHeight) + restHeight + 14, 640)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                focus: win.pinned
                Keys.onEscapePressed: win.setOpen(false)

                HoverHandler {
                    id: notchHover
                    onHoveredChanged: if (!hovered) leaveTimer.restart()
                }

                // The bottom bar's surface and outline. The top corners sit above the
                // screen edge, so only the bottom ones show.
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: -notch.radius
                    radius: notch.radius
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (notch.mode === "notifs")
                            GlobalStates.sidebarRightOpen = true;
                        else if (root.openedByHover && win.panelOpen)
                            root.openedByHover = false; // a click pins a panel the mouse opened
                        else
                            win.setOpen(!win.panelOpen);
                    }
                }

                Mascot {
                    id: mascot
                    size: 18
                    showFace: false
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((notch.restHeight - height) / 2)
                    baseMood: root.playing ? "dance" : "idle"
                    Connections {
                        target: root
                        function onJumpRequested() { mascot.jump(); }
                    }
                    // only a toy while the island is open; closed, a click opens it
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: notch.mode === "panel"
                        onClicked: mascot.poke()
                    }
                }

                Item {
                    id: content
                    readonly property real implicitHeight: loader.item ? loader.item.implicitHeight : 0
                    x: 12
                    y: notch.restHeight + 2
                    width: notch.width - 24
                    height: notch.height - notch.restHeight - 8
                    clip: true
                    opacity: notch.mode !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Loader {
                        id: loader
                        width: parent.width
                        active: notch.mode !== ""
                        sourceComponent: notch.mode === "notifs" ? notifsView : panelView
                    }
                }
            }

            // ---------- notifications, whole ----------
            Component {
                id: notifsView
                NotificationListView {
                    implicitHeight: contentHeight
                    height: contentHeight
                    popup: true
                    expandAll: true
                }
            }

            // ---------- panel ----------
            Component {
                id: panelView
                ColumnLayout {
                    spacing: 6

                    // time (primary block) + weather (tertiary block)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Block {
                            Layout.fillWidth: true
                            tint: Appearance.colors.colPrimaryContainer
                            implicitHeight: 64
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10
                                StyledText {
                                    text: DateTime.time
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 34
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 13
                                    text: DateTime.longDate
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 13
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        Block {
                            tint: Appearance.colors.colTertiaryContainer
                            implicitWidth: 124
                            implicitHeight: 64
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                                    iconSize: 28
                                    color: Appearance.m3colors.m3onTertiaryContainer
                                }
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: Weather.data?.temp ?? "--°"
                                        font.family: "Space Grotesk"
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                        color: Appearance.m3colors.m3onTertiaryContainer
                                    }
                                    StyledText {
                                        visible: (Weather.data?.city ?? "") !== ""
                                        Layout.maximumWidth: 70
                                        text: Weather.data?.city ?? ""
                                        font.pixelSize: 10
                                        color: Appearance.m3colors.m3onTertiaryContainer
                                        opacity: 0.75
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // music, under time and weather (secondary block)
                    Block {
                        visible: root.hasPlayer
                        Layout.fillWidth: true
                        tint: Appearance.colors.colSecondaryContainer
                        implicitHeight: 60
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            ClippingRectangle {
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer1
                                Image {
                                    anchors.fill: parent
                                    source: MprisController.activePlayer?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(88, 88)
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                StyledText {
                                    Layout.fillWidth: true
                                    text: MprisController.activePlayer?.trackTitle ?? ""
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSecondaryContainer
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: MprisController.activePlayer?.trackArtist ?? ""
                                    font.pixelSize: 11
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                }
                            }
                            Repeater {
                                model: [
                                    { icon: "skip_previous", act: () => MprisController.previous() },
                                    { icon: root.playing ? "pause" : "play_arrow", act: () => MprisController.togglePlaying() },
                                    { icon: "skip_next", act: () => MprisController.next() }
                                ]
                                delegate: RippleButton {
                                    required property var modelData
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    padding: 0
                                    buttonRadius: 17
                                    onClicked: modelData.act()
                                    contentItem: Item {
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            iconSize: 22
                                            fill: 1
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // quick tools (bar-group block) + performance mosaic
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Block {
                            Layout.fillWidth: true
                            tint: Appearance.colors.colLayer1
                            implicitHeight: 80
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 0
                                QuickTool {
                                    icon: "screenshot_region"
                                    label: "Print"
                                    onClicked: {
                                        win.setOpen(false);
                                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                                    }
                                }
                                QuickTool {
                                    icon: "colorize"
                                    label: "Cor"
                                    onClicked: {
                                        win.setOpen(false);
                                        Quickshell.execDetached(["bash", "-c", "sleep 0.3; hyprpicker -a"]);
                                    }
                                }
                                QuickTool {
                                    icon: Notifications.silent ? "notifications_paused" : "notifications_active"
                                    label: "Silêncio"
                                    toggled: Notifications.silent
                                    onClicked: Notifications.silent = !Notifications.silent
                                }
                                QuickTool {
                                    id: ledTool
                                    icon: "light_mode"
                                    label: "LED"
                                    onClicked: {
                                        ledPopup.anchorItem = ledTool;
                                        ledPopup.open = !ledPopup.open;
                                    }
                                }
                                QuickTool {
                                    visible: Battery.available
                                    icon: Battery.isCharging ? "battery_charging_full" : "smartphone"
                                    label: `${Math.round(Battery.percentage * 100)}%`
                                }
                            }
                        }
                        // the four Mosaic blocks fill up from the bottom
                        Block {
                            tint: Appearance.colors.colLayer1
                            implicitWidth: 80
                            implicitHeight: 80
                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 4
                                FillTile { value: ResourceUsage.cpuUsage; label: "CPU"; tone: Appearance.colors.colPrimary; onTone: Appearance.colors.colOnPrimary }
                                FillTile { value: ResourceUsage.memoryUsedPercentage; label: "RAM"; tone: Appearance.colors.colSecondary; onTone: Appearance.colors.colOnSecondary }
                                FillTile { value: gpuBusy.value; label: "GPU"; tone: Appearance.colors.colTertiary; onTone: Appearance.m3colors.m3onTertiary }
                                FillTile { value: ResourceUsage.swapUsedPercentage; label: "SWP"; tone: Appearance.colors.colOnLayer0; onTone: Appearance.m3colors.m3background }
                            }
                        }
                    }
                }
            }

            // GPU load (amdgpu), read only while the panel is open
            QtObject {
                id: gpuBusy
                property real value: 0
            }
            FileView {
                id: gpuFile
                path: "/sys/class/drm/card1/device/gpu_busy_percent"
                onLoaded: gpuBusy.value = (parseInt(text()) || 0) / 100
            }
            Timer {
                running: win.panelOpen
                repeat: true
                triggeredOnStart: true
                interval: 2000
                onTriggered: gpuFile.reload()
            }

            Bar.LedPopup {
                id: ledPopup
                atTop: true
                edgeMargin: notch.height + 6
            }
        }
    }

    // A block inside the island, like a bar group, in one Matugen tone
    component Block: Rectangle {
        property color tint: Appearance.colors.colLayer1
        color: tint
        radius: Appearance.rounding.small
    }

    // A round quick tool with a caption under it: fixed cell, icon truly centered
    component QuickTool: Item {
        id: tool
        required property string icon
        required property string label
        property bool toggled: false
        signal clicked()
        Layout.fillWidth: true
        implicitWidth: 52
        implicitHeight: 66
        RippleButton {
            id: toolButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 42
            height: 42
            padding: 0
            buttonRadius: 21
            toggled: tool.toggled
            colBackground: Appearance.colors.colLayer2
            onClicked: tool.clicked()
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: tool.icon
                    iconSize: 20
                    color: tool.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: toolButton.bottom
            anchors.topMargin: 4
            text: tool.label
            font.family: "Space Grotesk"
            font.pixelSize: 11
            color: Appearance.colors.colSubtext
        }
    }

    // One performance reading as a Mosaic block that fills from the bottom,
    // with the number inside (dark on the filled part, light on the empty one)
    component FillTile: Item {
        id: tile
        required property real value
        required property string label
        required property color tone
        required property color onTone
        readonly property real level: Math.max(0, Math.min(1, value))
        width: 32
        height: 32
        Rectangle {
            anchors.fill: parent
            radius: 7
            color: ColorUtils.transparentize(tile.tone, 0.8)
            clip: true
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.round(parent.height * tile.level)
                color: tile.tone
                Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
            }
        }
        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -3
            text: Math.round(tile.level * 100)
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: tile.level > 0.5 ? tile.onTone : Appearance.colors.colOnLayer0
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            text: tile.label
            font.family: "JetBrains Mono"
            font.pixelSize: 7
            color: tile.level > 0.15 ? tile.onTone : Appearance.colors.colSubtext
        }
    }
}
