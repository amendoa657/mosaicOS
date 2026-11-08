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

// Stage Manager: push the pointer against the left edge and the other
// workspaces of that screen slide in as stacks of their real windows, the one
// you used last in front, up to two more behind it, like on macOS. A click on
// a stack goes to that workspace; leaving the column closes it.
// - The edge is a 2 px window on each screen; the pointer has to rest there
//   for 250 ms, so crossing it on the way to something else does nothing.
// - The pictures are the windows themselves (ScreencopyView of each toplevel,
//   the same capture the ii overview uses), only while the column is open.
// - On and off: Config.options.mosaicStage.enabled (Áreas tab, Super+Shift+Tab).
//   Off, the edge does not exist.
// - IPC: qs -c mosaic ipc call stage open|openOn <screen>|close|toggleEnabled
// Idea from pocket-dots' Stage Manager (diegoMalagrida/pocket-dots, GPL-3.0).
Scope {
    id: root
    readonly property bool enabled: Config.options.mosaicStage?.enabled ?? true
    property string openScreen: "" // the screen whose column is out ("" = none)

    function toggleEnabled() {
        Config.options.mosaicStage.enabled = !root.enabled;
        root.openScreen = "";
    }
    IpcHandler {
        target: "stage"
        function open(): void { root.openScreen = Hyprland.focusedMonitor?.name ?? ""; }
        function openOn(screen: string): void { root.openScreen = screen; }
        function close(): void { root.openScreen = ""; }
        function toggleEnabled(): void { root.toggleEnabled(); }
    }
    GlobalShortcut {
        name: "mosaicStageToggle"
        description: "Liga e desliga o Stage Manager do Mosaic OS"
        onPressed: root.toggleEnabled()
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property var modelData
            readonly property bool isOpen: root.openScreen === perScreen.modelData.name
            readonly property var hlMonitor: Hyprland.monitors.values.find(m => m.name === perScreen.modelData.name) ?? null
            readonly property int activeId: perScreen.hlMonitor?.activeWorkspace?.id ?? 1
            readonly property bool fullscreenHere: HyprlandData.windowList.some(w => w.workspace?.id === perScreen.activeId && w.fullscreen >= 2)
            // the other workspaces of this screen that have windows, each with its
            // windows newest first (focusHistoryID: 0 = the last one used)
            readonly property var stacks: {
                const byWs = {};
                for (const w of HyprlandData.windowList) {
                    const id = w.workspace?.id ?? 0;
                    if (id <= 0 || id === perScreen.activeId || HyprlandData.monitors.find(m => m.id === w.monitor)?.name !== perScreen.modelData.name)
                        continue;
                    (byWs[id] = byWs[id] ?? []).push(w);
                }
                return Object.keys(byWs).map(Number).sort((a, b) => a - b).map(id => ({
                    id: id,
                    windows: byWs[id].sort((a, b) => a.focusHistoryID - b.focusHistoryID).slice(0, 3)
                }));
            }
            MosaicSpring { id: slide; response: 0.4; damping: 0.84; springBack: false; closeMs: 200; target: perScreen.isOpen ? 1 : 0 }

            // the edge
            PanelWindow {
                screen: perScreen.modelData
                visible: root.enabled && !perScreen.isOpen && !perScreen.fullscreenHere
                anchors { top: true; bottom: true; left: true }
                implicitWidth: 2
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "quickshell:stageEdge"
                WlrLayershell.layer: WlrLayer.Overlay
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: dwell.restart()
                    onExited: dwell.stop()
                }
                Timer {
                    id: dwell
                    interval: 250
                    onTriggered: if (perScreen.stacks.length > 0) root.openScreen = perScreen.modelData.name
                }
            }

            // the column
            PanelWindow {
                id: column
                screen: perScreen.modelData
                visible: perScreen.isOpen || slide.value > 0.01
                anchors { top: true; bottom: true; left: true }
                implicitWidth: 300
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "quickshell:stage"
                WlrLayershell.layer: WlrLayer.Overlay
                mask: Region { item: stackList }

                // leaving the column closes it (a moment later, so a wobble on the way out doesn't)
                HoverHandler {
                    id: hover
                    onHoveredChanged: if (hovered) leave.stop(); else leave.restart()
                }
                Timer {
                    id: leave
                    interval: 300
                    onTriggered: if (perScreen.isOpen && !hover.hovered) root.openScreen = ""
                }
                Component.onCompleted: leave.restart() // if the pointer never comes in

                Column {
                    id: stackList
                    x: 18 - (1 - slide.value) * 320
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 22
                    opacity: Math.min(1, slide.value * 1.4)

                    Repeater {
                        model: perScreen.stacks
                        delegate: Item {
                            id: stack
                            required property var modelData
                            required property int index
                            width: 250
                            height: 150
                            // each stack comes in a moment after the one above
                            property real born: 0
                            Behavior on born { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                            Timer { running: perScreen.isOpen; interval: 40 + stack.index * 45; onTriggered: stack.born = 1 }
                            opacity: stack.born
                            transform: Translate { x: (1 - stack.born) * -30 }
                            MosaicSpring { id: lift; response: 0.3; damping: 0.75; target: stackArea.containsMouse ? 1 : 0 }

                            // the windows, back to front
                            Repeater {
                                model: stack.modelData.windows.slice().reverse()
                                delegate: Rectangle {
                                    id: pane
                                    required property var modelData
                                    required property int index
                                    // 0 = in front
                                    readonly property int depth: stack.modelData.windows.length - 1 - pane.index
                                    readonly property var toplevel: ToplevelManager.toplevels.values.find(t => `0x${t.HyprlandToplevel?.address}` === pane.modelData.address) ?? null
                                    readonly property real aspect: Math.max(0.3, (pane.modelData.size?.[0] ?? 16) / Math.max(1, pane.modelData.size?.[1] ?? 9))
                                    height: 116 - pane.depth * 10
                                    width: Math.min(200, height * pane.aspect)
                                    x: 6 + pane.depth * 16 + lift.value * pane.depth * 6
                                    y: 22 - pane.depth * 11 - lift.value * pane.depth * 4
                                    opacity: 1 - pane.depth * 0.22
                                    radius: Appearance.rounding.small
                                    color: MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer1
                                    border.width: MosaicTheme.brutal ? 2 : 1
                                    border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
                                    clip: true
                                    HardShadow { visible: MosaicTheme.brutal && pane.depth === 0 }
                                    ScreencopyView {
                                        anchors.fill: parent
                                        anchors.margins: pane.border.width
                                        captureSource: perScreen.isOpen ? pane.toplevel : null
                                        live: perScreen.isOpen // live only while the column is out, like the ii overview
                                    }
                                    Grain { radius: pane.radius; amount: MosaicTheme.grainSidebars }
                                }
                            }
                            // the app's icon, and the workspace number
                            Row {
                                x: 0
                                y: stack.height - 30
                                spacing: 8
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: MosaicTheme.r(9)
                                    color: MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer0
                                    border.width: MosaicTheme.brutal ? 1.5 : 1
                                    border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
                                    Image {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        sourceSize: Qt.size(40, 40)
                                        source: Quickshell.iconPath(AppSearch.guessIcon(stack.modelData.windows[0]?.class ?? ""), "application-x-executable")
                                    }
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String(stack.modelData.id)
                                    font.family: MosaicTheme.fontDisplay
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: "white"
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                                }
                            }
                            MouseArea {
                                id: stackArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.openScreen = "";
                                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${stack.modelData.id} })`);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
