pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar
import qs.modules.mosaic.island

// The Mosaic OS dock: the protagonist at the bottom, in the island's style (the
// bar's surface and outline, soft blended Matugen blocks inside). Three blocks:
// the Mosaic mark (opens the launcher; right click, the left sidebar), the apps
// (pinned and open, springy magnification under the mouse, a bounce while an app
// launches) and the status (tray, network, bluetooth, volume, clock; opens the
// right sidebar, scroll changes the volume). It reserves its space, like the bar did.
Scope {
    id: root
    readonly property real dockHeight: 60
    readonly property real gap: 8 // from the screen edge
    readonly property real lift: 46 // room above the dock for magnified icons and tooltips

    function softBlock(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.32); }
    function softTone(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.72); }
    function toneFor(i) {
        const c = Appearance.colors;
        return [c.colPrimary, c.colSecondary, c.colTertiary, ColorUtils.mix(c.colSecondary, c.colTertiary, 0.5)][i % 4];
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked
            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: root.dockHeight + root.gap + root.lift
            // floats over the windows: shown on an empty workspace, otherwise only
            // when the mouse goes down to the bottom edge (and while it stays on it)
            exclusiveZone: 0
            readonly property int workspaceId: Hyprland.monitorFor(win.screen)?.activeWorkspace?.id ?? -1
            readonly property bool emptyWorkspace: !HyprlandData.windowList.some(w => w.workspace.id === win.workspaceId)
            property bool hovering: false
            readonly property bool shown: emptyWorkspace || hovering
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) { leaveTimer.stop(); win.hovering = true; }
                    else leaveTimer.restart();
                }
            }
            Timer { id: leaveTimer; interval: 400; onTriggered: win.hovering = false }
            Item { // the bottom edge that brings the dock up
                id: edgeSensor
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: dock.width
                height: 3
            }
            color: "transparent"
            WlrLayershell.namespace: "quickshell:dock"
            mask: Region { item: win.shown ? dock : edgeSensor }

            Rectangle {
                id: dock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.gap
                transform: Translate {
                    y: win.shown ? 0 : root.dockHeight + root.gap + 4
                    Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                }
                height: root.dockHeight
                width: row.implicitWidth + 16
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    height: parent.height - 16
                    spacing: 6

                    // ---------- start: the Mosaic mark ----------
                    Block {
                        id: startBlock
                        Layout.fillHeight: true
                        implicitWidth: height
                        tint: root.softBlock(Appearance.colors.colPrimary)
                        tint2: root.softBlock(Appearance.colors.colSecondary)
                        Mascot {
                            id: mark
                            anchors.centerIn: parent
                            size: 24
                            showFace: false
                            scale: startArea.containsMouse ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }
                        MouseArea {
                            id: startArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: event => {
                                mark.jump();
                                if (event.button === Qt.RightButton)
                                    GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
                                else
                                    GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                            }
                        }
                    }

                    // ---------- apps ----------
                    Block {
                        Layout.fillHeight: true
                        implicitWidth: apps.implicitWidth + 8
                        tint: Appearance.colors.colLayer1
                        Row {
                            id: apps
                            anchors.centerIn: parent
                            height: parent.height
                            Repeater {
                                model: ScriptModel {
                                    objectProp: "appId"
                                    values: TaskbarApps.apps
                                }
                                // One app: its icon (magnified when the mouse is near), a soft block behind
                                // it when it is the active one, and one dot per window (up to three)
                                delegate: Item {
                                    id: app
                                    required property var modelData
                                    required property int index
                                    readonly property bool isSeparator: modelData.appId === "SEPARATOR"
                                    readonly property var toplevels: modelData.toplevels
                                    readonly property bool isActive: toplevels.some(t => t.activated)
                                    readonly property color tone: root.toneFor(index) ?? "transparent"
                                    property var desktopEntry: DesktopEntries.heuristicLookup(modelData.appId)
                                    // 1 while the mouse is on it: the icon pops up with a little overshoot
                                    readonly property real magnify: mouse.containsMouse ? 1 : 0

                                    width: isSeparator ? 10 : 46
                                    height: apps.height

                                    Connections {
                                        target: DesktopEntries
                                        function onApplicationsChanged() { app.desktopEntry = DesktopEntries.heuristicLookup(app.modelData.appId); }
                                    }

                                    Rectangle { // separator between pinned and the rest
                                        visible: app.isSeparator
                                        anchors.centerIn: parent
                                        width: 2
                                        height: parent.height * 0.5
                                        radius: 1
                                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
                                    }

                                    Item {
                                        id: lifted
                                        visible: !app.isSeparator
                                        anchors.fill: parent
                                        property real bounce: 0
                                        transform: Translate { y: lifted.bounce }

                                        Rectangle { // the active app sits on a block in its tone
                                            anchors.centerIn: parent
                                            width: 40
                                            height: 40
                                            radius: Appearance.rounding.small
                                            color: root.softBlock(app.tone)
                                            opacity: app.isActive ? 1 : mouse.containsMouse ? 0.45 : 0
                                            Behavior on opacity { NumberAnimation { duration: 180 } }
                                        }
                                        IconImage {
                                            id: icon
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -2
                                            implicitSize: 30
                                            source: Quickshell.iconPath(AppSearch.guessIcon(app.modelData.appId), "image-missing")
                                            transformOrigin: Item.Bottom
                                            scale: 1 + 0.22 * app.magnify
                                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                        }
                                        Row { // one dot per window
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 1
                                            spacing: 3
                                            Repeater {
                                                model: Math.min(app.toplevels.length, 3)
                                                delegate: Rectangle {
                                                    width: app.isActive ? 10 : 4
                                                    height: 4
                                                    radius: 2
                                                    color: app.isActive ? app.tone : root.softTone(app.tone)
                                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                                                }
                                            }
                                        }
                                        SequentialAnimation { // launching: hops until it shows up
                                            id: launchBounce
                                            loops: 3
                                            NumberAnimation { target: lifted; property: "bounce"; to: -12; duration: 170; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: lifted; property: "bounce"; to: 0; duration: 330; easing.type: Easing.OutBounce }
                                        }
                                    }

                                    MouseArea {
                                        id: mouse
                                        enabled: !app.isSeparator
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                        property int lastFocused: -1
                                        onClicked: event => {
                                            if (event.button === Qt.RightButton) {
                                                TaskbarApps.togglePin(app.modelData.appId);
                                            } else if (event.button === Qt.MiddleButton || app.toplevels.length === 0) {
                                                app.desktopEntry?.execute();
                                                launchBounce.restart();
                                            } else {
                                                lastFocused = (lastFocused + 1) % app.toplevels.length;
                                                app.toplevels[lastFocused].activate();
                                            }
                                        }
                                    }
                                    StyledToolTip {
                                        extraVisibleCondition: mouse.containsMouse
                                        text: app.desktopEntry?.name ?? app.modelData.appId
                                    }
                                }
                            }
                        }
                    }

                    // ---------- status and clock ----------
                    Block {
                        Layout.fillHeight: true
                        implicitWidth: statusRow.implicitWidth + 20
                        tint: root.softBlock(Appearance.colors.colSecondary)
                        tint2: root.softBlock(Appearance.colors.colTertiary)
                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 12
                            Bar.SysTray {
                                Layout.fillHeight: true
                                invertSide: true
                                showSeparator: false
                            }
                            MouseArea {
                                implicitWidth: statusContent.implicitWidth
                                implicitHeight: statusContent.implicitHeight
                                onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                                onWheel: wheel => {
                                    if (wheel.angleDelta.y > 0) Audio.incrementVolume();
                                    else if (wheel.angleDelta.y < 0) Audio.decrementVolume();
                                }
                                RowLayout {
                                    id: statusContent
                                    spacing: 10
                                    StatusIcon {
                                        visible: Notifications.silent
                                        text: "notifications_off"
                                    }
                                    StatusIcon { text: Network.materialSymbol }
                                    StatusIcon {
                                        visible: BluetoothStatus.available
                                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                                    }
                                    StatusIcon {
                                        readonly property real volume: Audio.sink?.audio?.volume ?? 0
                                        text: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : volume < 0.01 ? "volume_mute" : volume < 0.5 ? "volume_down" : "volume_up"
                                    }
                                    ColumnLayout {
                                        Layout.leftMargin: 2
                                        spacing: -2
                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            text: DateTime.time
                                            font.family: "Space Grotesk"
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnLayer0
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            text: DateTime.shortDate
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 10
                                            color: Appearance.colors.colOnLayer0
                                            opacity: 0.75
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Block: Rectangle {
        id: block
        property color tint: Appearance.colors.colLayer1
        property color tint2: tint // the tone it flows into, left to right
        radius: Appearance.rounding.small
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: block.tint }
            GradientStop { position: 1; color: block.tint2 }
        }
    }

    component StatusIcon: MaterialSymbol {
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnLayer0
    }
}
