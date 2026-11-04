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
import qs.modules.ii.bar as Bar

// Mosaic OS island: a notch on the top edge with the living Mosaic mark.
// - Notifications show up whole inside it (the ii notification widget, actions
//   included); the mark jumps.
// - Click opens the panel: music (when there is a player), the time and the quick
//   tools that left the bottom bar (screenshot, color picker, do not disturb,
//   LED strip, phone battery).
// It floats over windows (no exclusive zone) and uses the bottom bar's look.
Scope {
    id: root

    // The panel opens on one screen at a time (the one clicked, or the focused
    // one for IPC); each window keeps its own state
    property string openScreen: ""
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
            implicitWidth: 520
            implicitHeight: 640
            mask: Region {
                item: notch
            }
            readonly property bool panelOpen: root.openScreen === win.screen.name
            function setOpen(open) {
                root.openScreen = open ? win.screen.name : (root.openScreen === win.screen.name ? "" : root.openScreen);
            }

            // While open it takes the keyboard (Esc closes), like the ii sidebars
            WlrLayershell.keyboardFocus: win.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Click outside closes it (but not while the LED menu, opened from here, is up)
            HyprlandFocusGrab {
                active: win.panelOpen && !ledPopup.open
                windows: [win]
                onCleared: win.setOpen(false)
            }

            Item {
                id: notch
                // what is open: notifications win over the panel
                readonly property string mode: root.hasNotifs ? "notifs" : win.panelOpen ? "panel" : ""
                readonly property real restWidth: 64
                readonly property real restHeight: 32
                readonly property real radius: Appearance.rounding.windowRounding

                anchors.horizontalCenter: parent.horizontalCenter
                width: mode === "" ? restWidth : 440
                height: mode === "" ? restHeight : Math.min(content.implicitHeight + restHeight + 12, 620)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                // Same surface as the bottom bar. The top corners sit above the
                // screen edge, so only the bottom ones show (plain rounded rect:
                // smooth edges, no per-corner path).
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: -notch.radius
                    radius: notch.radius
                    color: Config.options.bar.showBackground ? Appearance.colors.colLayer0 : "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    antialiasing: true
                }

                focus: win.panelOpen
                Keys.onEscapePressed: win.setOpen(false)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (notch.mode === "notifs")
                            GlobalStates.sidebarRightOpen = true;
                        else
                            win.setOpen(!win.panelOpen);
                    }
                }

                Mascot {
                    id: mascot
                    size: 18
                    showFace: false
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (notch.restHeight - height) / 2
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
                    anchors.horizontalCenter: parent.horizontalCenter
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

            // ---------- panel: music + time + quick tools ----------
            Component {
                id: panelView
                ColumnLayout {
                    spacing: 14

                    // music
                    RowLayout {
                        visible: root.hasPlayer
                        Layout.fillWidth: true
                        spacing: 12
                        ClippingRectangle {
                            implicitWidth: 52
                            implicitHeight: 52
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1
                            Image {
                                anchors.fill: parent
                                source: MprisController.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(104, 104)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                Layout.fillWidth: true
                                text: MprisController.activePlayer?.trackTitle ?? ""
                                font.family: "Space Grotesk"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: MprisController.activePlayer?.trackArtist ?? ""
                                font.pixelSize: 12
                                color: Appearance.colors.colSubtext
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
                                implicitWidth: 36
                                implicitHeight: 36
                                buttonRadius: 18
                                onClicked: modelData.act()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    iconSize: 22
                                    fill: 1
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }

                    // time + weather (top right)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        StyledText {
                            text: DateTime.time
                            font.family: "Space Grotesk"
                            font.pixelSize: 38
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                            text: DateTime.longDate
                            font.family: "Space Grotesk"
                            font.pixelSize: 13
                            color: Appearance.colors.colSubtext
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 6
                            MaterialSymbol {
                                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                                iconSize: 26
                                color: Appearance.colors.colOnLayer0
                            }
                            ColumnLayout {
                                spacing: 0
                                StyledText {
                                    text: Weather.data?.temp ?? "--°"
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    visible: (Weather.data?.city ?? "") !== ""
                                    text: Weather.data?.city ?? ""
                                    font.pixelSize: 10
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }

                    // quick tools (left the bottom bar) + performance circles
                    RowLayout {
                        Layout.fillWidth: true
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
                        Item { Layout.fillWidth: true }
                        // CPU, RAM, GPU and swap, a square of circles
                        GridLayout {
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 6
                            PerfCircle { icon: "memory"; value: ResourceUsage.cpuUsage; tip: "CPU" }
                            PerfCircle { icon: "memory_alt"; value: ResourceUsage.memoryUsedPercentage; tip: "RAM" }
                            PerfCircle { icon: "gamepad"; value: gpuBusy.value; tip: "GPU" }
                            PerfCircle { icon: "swap_horiz"; value: ResourceUsage.swapUsedPercentage; tip: "Swap" }
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

    // A round quick tool with a caption under it: fixed cell, icon truly centered
    component QuickTool: Item {
        id: tool
        required property string icon
        required property string label
        property bool toggled: false
        signal clicked()
        implicitWidth: 58
        implicitHeight: 70
        RippleButton {
            id: toolButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: 48
            height: 48
            padding: 0
            buttonRadius: 24
            toggled: tool.toggled
            colBackground: Appearance.colors.colLayer1
            onClicked: tool.clicked()
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: tool.icon
                    iconSize: 22
                    color: tool.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: toolButton.bottom
            anchors.topMargin: 5
            text: tool.label
            font.family: "Space Grotesk"
            font.pixelSize: 11
            color: Appearance.colors.colSubtext
        }
    }

    // One performance reading as a filled ring with its icon in the middle
    component PerfCircle: ClippedFilledCircularProgress {
        id: perf
        required property string icon
        required property string tip
        implicitSize: 32
        lineWidth: Appearance.rounding.unsharpen
        enableAnimation: false
        colPrimary: perf.value > 0.9 ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
        MaterialSymbol {
            anchors.centerIn: parent
            text: perf.icon
            iconSize: 15
            fill: 1
            color: Appearance.colors.colOnSecondaryContainer
        }
    }
}
