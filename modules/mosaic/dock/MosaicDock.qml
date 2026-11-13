pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mosaic.island

// The Mosaic OS dock: a pane of light glass floating at the bottom, with the
// icons resting on it. From left to right: the Mosaic mark (opens the launcher;
// right click, the left sidebar), the apps (pinned and open) and the status
// (network, bluetooth, volume; opens the right sidebar, scroll changes the
// volume). The clock lives in the island, and so does the tray.
// - Under the mouse the icons rise in a gentle wave, like macOS: the closest one
//   grows the most, its neighbours a little. One spring follows the mouse and
//   every icon reads it, so nothing restarts on each pixel and it never stutters.
// - It floats over the windows: shown on an empty workspace, otherwise it comes
//   up when the mouse reaches the bottom edge.
Scope {
    id: root
    // macOS theme: Apple's dock: bigger icons, the real magnification, a white dot
    // under open apps, and no status area (that is in the menu bar)
    readonly property bool mac: MosaicTheme.mac
    readonly property real dockHeight: mac ? 60 : 58
    readonly property real gap: mac ? 6 : 4 // from the screen edge
    readonly property real lift: mac ? 54 : 46 // room above the dock for the wave and the tooltips
    readonly property real cell: mac ? 50 : 46 // one app's width
    readonly property real iconSize: mac ? 40 : 34
    readonly property real magnify: mac ? 0.32 : 0.2 // how much bigger the icon under the mouse gets
    readonly property real rise: mac ? 10 : 7

    // the glass: a light, see-through pane (alpha above 0.3, so hyprglass bends it)
    // a thin tint: the strong liquid glass behind it (hypr/mosaic.lua, preset "dock")
    // does the work; the sheen that used to sit on top read as a grey bar
    // Dock tab: darkness (toward black) and opacity (how solid the tint is)
    readonly property color glassFill: {
        // retro themes (Horizonte): a warm dark film instead of a light one
        const film = MosaicTheme.retro ? Appearance.m3colors.m3surfaceContainer : ColorUtils.mix("#ffffff", Appearance.colors.colLayer0, 0.08);
        const tint = ColorUtils.mix("#000000", film, Config.options.mosaicDock.darkness);
        return Qt.rgba(tint.r, tint.g, tint.b, MosaicTheme.paneAlpha(Config.options.mosaicDock.opacity));
    }
    readonly property color glassEdge: Qt.rgba(1, 1, 1, 0.16)

    // Icons that Matugen repaints with the wallpaper colours (the Mosaic Store one
    // and the Neovim one, in ~/.local/share/icons). Qt keeps icons in a cache, so a
    // repainted file only showed up after restarting the shell. For these the dock
    // loads the file itself with "?v=N" at the end: when the file changes, N goes
    // up, the address is new, and Qt reads the file again. No restart needed.
    readonly property string userIcons: Quickshell.env("HOME") + "/.local/share/icons/hicolor/scalable/apps/"
    readonly property var liveIcons: ["mosaic-store", "nvim-matugen"]
    property var iconVersions: ({})
    function iconSource(name) {
        if (root.liveIcons.includes(name))
            return "file://" + root.userIcons + name + ".svg?v=" + (root.iconVersions[name] ?? 0);
        return Quickshell.iconPath(name, "image-missing");
    }
    Variants {
        model: root.liveIcons
        delegate: FileView {
            required property string modelData
            path: root.userIcons + modelData + ".svg"
            watchChanges: true
            printErrors: false
            onFileChanged: {
                const v = Object.assign({}, root.iconVersions); // a new object, so bindings notice
                v[modelData] = (v[modelData] ?? 0) + 1;
                root.iconVersions = v;
                reload();
            }
        }
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
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:dock"

            // ---------- showing and hiding ----------
            readonly property int workspaceId: Hyprland.monitorFor(win.screen)?.activeWorkspace?.id ?? -1
            readonly property bool emptyWorkspace: !HyprlandData.windowList.some(w => w.workspace.id === win.workspaceId)
            property bool hovering: false
            readonly property bool shown: emptyWorkspace || hovering
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        leaveTimer.stop();
                        win.hovering = true;
                    } else {
                        leaveTimer.restart();
                    }
                }
            }
            Timer {
                id: leaveTimer
                interval: 400
                onTriggered: win.hovering = false
            }
            // what catches the mouse: a wide strip at the bottom edge while hidden,
            // the whole dock down to the edge while shown (no gap to fall through)
            Item {
                id: hitArea
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: dock.width + (win.shown ? 24 : 160)
                height: win.shown ? root.dockHeight + root.gap + 6 : 10
            }
            mask: Region { item: hitArea }
            MosaicSpring { id: showSpring; response: 0.42; damping: 0.78; target: win.shown ? 1 : 0; Component.onCompleted: settle(target) }

            // ---------- the glass ----------
            Rectangle {
                id: dock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.gap
                height: root.dockHeight
                width: row.implicitWidth + 20
                radius: MosaicTheme.r(20)
                // brutal themes: a solid slab with a thick outline and a hard shadow instead of glass
                color: MosaicTheme.brutal ? MosaicTheme.slab : root.glassFill
                border.width: MosaicTheme.brutal ? MosaicTheme.border : 1
                border.color: MosaicTheme.brutal ? MosaicTheme.ink : root.glassEdge
                HardShadow {}
                Grain { radius: dock.radius; amount: MosaicTheme.grainDock } // film grain (retro themes)
                transform: Translate { y: (1 - showSpring.value) * (root.dockHeight + root.gap + 6) }
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 4

                    // ---------- the Mosaic mark ----------
                    Item {
                        Layout.fillHeight: true
                        implicitWidth: root.cell
                        Mascot {
                            id: mark
                            anchors.centerIn: parent
                            size: 26
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
                                    GlobalStates.searchOpen = !GlobalStates.searchOpen; // the start menu in the island
                            }
                        }
                    }

                    Divider {}

                    // ---------- the apps ----------
                    Row {
                        id: apps
                        Layout.fillHeight: true

                        // The wave: one spring follows the mouse along the row, and
                        // each icon grows by how close it is to that point (a bell
                        // curve). `wave` fades the whole effect in and out.
                        HoverHandler {
                            id: appsHover
                            onHoveredChanged: if (hovered) pointer.settle(point.position.x)
                        }
                        readonly property real pointerX: appsHover.point.position.x
                        onPointerXChanged: if (appsHover.hovered) pointer.target = pointerX
                        MosaicSpring { id: pointer; response: 0.16; damping: 1; epsilon: 0.3 }
                        MosaicSpring { id: wave; response: 0.3; damping: 0.9; epsilon: 0.002; target: appsHover.hovered ? 1 : 0 }

                        Repeater {
                            model: ScriptModel {
                                objectProp: "appId"
                                values: TaskbarApps.apps
                            }
                            // One app: its icon (rising with the wave), one dot per open window
                            delegate: Item {
                                id: app
                                required property var modelData
                                readonly property bool isSeparator: modelData.appId === "SEPARATOR"
                                readonly property var toplevels: modelData.toplevels
                                readonly property bool isActive: toplevels.some(t => t.activated)
                                property var desktopEntry: DesktopEntries.heuristicLookup(modelData.appId)
                                // 0..1: how much this icon rises (bell curve around the mouse, ~1.2 icons wide)
                                readonly property real near: {
                                    if (isSeparator || wave.value <= 0.001)
                                        return 0;
                                    const d = (x + width / 2 - pointer.value) / root.cell;
                                    return Math.exp(-d * d / (root.mac ? 1.8 : 1.4)) * wave.value;
                                }

                                width: isSeparator ? 14 : root.cell
                                height: apps.height

                                Connections {
                                    target: DesktopEntries
                                    function onApplicationsChanged() { app.desktopEntry = DesktopEntries.heuristicLookup(app.modelData.appId); }
                                }

                                Rectangle { // between pinned and the rest
                                    visible: app.isSeparator
                                    anchors.centerIn: parent
                                    width: 1
                                    height: parent.height * 0.42
                                    color: root.glassEdge
                                }

                                Item {
                                    id: lifted
                                    visible: !app.isSeparator
                                    anchors.fill: parent
                                    property real bounce: 0
                                    transform: Translate { y: lifted.bounce - root.rise * app.near }

                                    IconImage {
                                        id: icon
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -3
                                        implicitSize: root.iconSize
                                        source: root.iconSource(AppSearch.guessIcon(app.modelData.appId))
                                        transformOrigin: Item.Bottom
                                        scale: 1 + root.magnify * app.near // subtle (20%); macOS: 32%
                                    }
                                    // one dot per window (up to three); the focused app's are longer
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        spacing: 3
                                        Repeater {
                                            model: root.mac ? Math.min(app.toplevels.length, 1) : Math.min(app.toplevels.length, 3)
                                            delegate: Rectangle {
                                                width: root.mac ? 4 : app.isActive ? 8 : 4
                                                height: 4
                                                radius: MosaicTheme.r(2)
                                                color: root.mac ? Qt.rgba(1, 1, 1, 0.8) : app.isActive ? Appearance.colors.colPrimary : Qt.rgba(1, 1, 1, 0.55)
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

                    Divider { visible: !root.mac }

                    // ---------- status ----------
                    MouseArea {
                        id: statusArea
                        visible: !root.mac
                        Layout.fillHeight: true
                        implicitWidth: statusRow.implicitWidth + 24
                        hoverEnabled: true
                        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                        onWheel: wheel => {
                            if (wheel.angleDelta.y > 0) Audio.incrementVolume();
                            else if (wheel.angleDelta.y < 0) Audio.decrementVolume();
                        }
                        Rectangle { // a soft pad under the mouse
                            anchors.centerIn: parent
                            width: parent.width - 4
                            height: 38
                            radius: MosaicTheme.r(13)
                            color: Qt.rgba(1, 1, 1, statusArea.containsMouse ? 0.10 : 0)
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 12
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
                        }
                    }
                }
            }
        }
    }

    // a thin line of light between the sections
    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 26
        color: MosaicTheme.brutal ? MosaicTheme.ink : Qt.rgba(1, 1, 1, 0.16)
    }

    component StatusIcon: MaterialSymbol {
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnLayer0
    }
}
