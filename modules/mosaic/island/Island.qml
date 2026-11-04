pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    property bool panelOpen: false
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
        function toggle(): void { root.panelOpen = !root.panelOpen; }
        function close(): void { root.panelOpen = false; }
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

            Item {
                id: notch
                // what is open: notifications win over the panel
                readonly property string mode: root.hasNotifs ? "notifs" : root.panelOpen ? "panel" : ""
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

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (notch.mode === "notifs")
                            GlobalStates.sidebarRightOpen = true;
                        else
                            root.panelOpen = !root.panelOpen;
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
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
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

                    // time
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
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                            text: DateTime.longDate ?? DateTime.date
                            font.family: "Space Grotesk"
                            font.pixelSize: 13
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                    }

                    // quick tools (left the bottom bar)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        QuickTool {
                            icon: "screenshot_region"
                            label: "Print"
                            onClicked: {
                                root.panelOpen = false;
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                            }
                        }
                        QuickTool {
                            icon: "colorize"
                            label: "Cor"
                            onClicked: {
                                root.panelOpen = false;
                                Quickshell.execDetached(["bash", "-c", "sleep 0.3; hyprpicker -a"]);
                            }
                        }
                        QuickTool {
                            icon: Notifications.silent ? "notifications_paused" : "notifications_active"
                            label: "Não perturbe"
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
                            onClicked: {}
                        }
                    }
                }
            }

            Bar.LedPopup {
                id: ledPopup
                atTop: true
                edgeMargin: notch.height + 6
            }
        }
    }

    // A round quick tool with a caption under it
    component QuickTool: ColumnLayout {
        id: tool
        required property string icon
        required property string label
        property bool toggled: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal shares of the row
        spacing: 4
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 52
            implicitHeight: 52
            buttonRadius: 26
            toggled: tool.toggled
            colBackground: Appearance.colors.colLayer1
            onClicked: tool.clicked()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: tool.icon
                iconSize: 22
                color: tool.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: tool.label
            font.family: "Space Grotesk"
            font.pixelSize: 11
            color: Appearance.colors.colSubtext
        }
    }
}
