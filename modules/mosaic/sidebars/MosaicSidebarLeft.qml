pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarRight.todo

// The Mosaic OS left sidebar: a full-height column glued to the left edge
// (Super+A, right click on the dock's mark), in the theme's style. Three tabs:
// Tradutor, Tarefas (the to-do list, moved from the right) and IA (the ii chat).
// The pages are the ii's own; the column, header and tabs are new. Pages are
// only created when first opened, and kept while the sidebar lives.
Scope {
    id: root
    readonly property real sidebarWidth: 460
    readonly property bool open: GlobalStates.sidebarLeftOpen
    property int tab: 0

    MosaicSpring { id: slide; response: 0.42; damping: 0.86; springBack: false; closeMs: 220; target: root.open ? 1 : 0 }

    // Click outside closes it: a transparent window covering the screen, under
    // the sidebar (Top layer; the sidebar is on Overlay). A click on it closes
    // the sidebar. (Hyprland's focus grab was dropping on its own right after the
    // sidebar opened, which closed it at the first click inside.)
    PanelWindow {
        visible: root.open
        screen: panel.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:sidebarCatcher"
        WlrLayershell.layer: WlrLayer.Top
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: GlobalStates.sidebarLeftOpen = false
        }
    }

    PanelWindow {
        id: panel
        visible: root.open || slide.value > 0.005
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        exclusiveZone: 0
        implicitWidth: root.sidebarWidth + MosaicTheme.shadow + 4
        color: "transparent"
        WlrLayershell.namespace: "quickshell:sidebarLeft"
        WlrLayershell.layer: WlrLayer.Overlay // above the click catcher
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors {
            top: true
            left: true
            bottom: true
        }
        // What takes the mouse: a still item the size of the column. The column itself
        // slides in with a transform, and Region doesn't follow transforms: masking
        // the column left the input region where the column was born (off the
        // screen), so clicks went through the sidebar to the catcher and closed it.
        Item {
            id: hitArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.sidebarWidth
        }
        mask: Region { item: hitArea }

        // brutal themes: the hard shadow falls on the inside (right) of the column
        Rectangle {
            visible: MosaicTheme.brutal
            x: column.x + MosaicTheme.shadow
            y: MosaicTheme.shadow
            width: column.width
            height: column.height
            color: MosaicTheme.shadowColor
            radius: column.radius
            transform: Translate { x: column.offset }
        }

        Rectangle {
            id: column
            readonly property real offset: -(1 - slide.value) * (root.sidebarWidth + 20)
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.sidebarWidth
            transform: Translate { x: column.offset }
            radius: Appearance.rounding.large
            // the Aparência tab's surface (darkness and opacity), shared with the island
            color: MosaicTheme.brutal ? MosaicTheme.slab : MosaicTheme.widgetFill(Appearance.colors.colLayer0)
            border.width: MosaicTheme.brutal ? MosaicTheme.border + 1 : 1
            border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
            focus: root.open
            Keys.onEscapePressed: GlobalStates.sidebarLeftOpen = false
            // square corners on the screen edge, round ones inside
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.radius
                color: parent.color
                Rectangle { anchors.top: parent.top; width: parent.width; height: column.border.width; color: column.border.color }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: column.border.width; color: column.border.color }
            }
            // film grain (retro themes). It runs one radius past the screen edge, where
            // the window cuts it, so only the inner corners are round, like the column.
            Grain {
                anchors.fill: undefined
                x: -column.radius
                width: column.width + column.radius
                height: column.height
                radius: column.radius
                amount: MosaicTheme.grainSidebars
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.rightMargin: 16 + MosaicTheme.shadow
                anchors.bottomMargin: 16 + MosaicTheme.shadow
                spacing: 12 + MosaicTheme.shadow

                // ---------- header: the mark and the tabs ----------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Mascot {
                        Layout.rightMargin: 6
                        size: 26
                        showFace: false
                    }
                    Repeater {
                        model: [
                            { icon: "translate", label: "Tradutor" },
                            { icon: "checklist", label: "Tarefas" },
                            { icon: "neurology", label: "IA" }
                        ]
                        delegate: Rectangle {
                            id: tabKey
                            required property var modelData
                            required property int index
                            readonly property bool on: root.tab === index
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Appearance.rounding.small
                            color: on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.32))
                                : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1)
                            border.width: MosaicTheme.brutal ? (on ? MosaicTheme.border : 1) : 0
                            border.color: MosaicTheme.ink
                            Behavior on color { ColorAnimation { duration: 180 } }
                            transform: Translate { x: tabShadow.sinkShift; y: tabShadow.sinkShift }
                            HardShadow { id: tabShadow; sink: tabArea.pressed || tabKey.on }
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    text: tabKey.modelData.icon
                                    iconSize: 18
                                    fill: tabKey.on ? 1 : 0
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    text: MosaicTheme.brutal ? tabKey.modelData.label.toUpperCase() : tabKey.modelData.label
                                    font.family: MosaicTheme.fontUi
                                    font.pixelSize: 13
                                    font.weight: tabKey.on ? Font.Bold : Font.Normal
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                onClicked: root.tab = tabKey.index
                            }
                        }
                    }
                }

                // ---------- the page ----------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1
                    border.width: MosaicTheme.border
                    border.color: MosaicTheme.ink
                    clip: true
                    HardShadow {}

                    // each page slides and fades in when its tab is chosen
                    Repeater {
                        model: [translatorPage, todoPage, aiPage]
                        delegate: Loader {
                            id: page
                            required property var modelData
                            required property int index
                            readonly property bool current: root.tab === index
                            property bool wanted: false
                            onCurrentChanged: if (current) wanted = true
                            Component.onCompleted: wanted = current
                            active: wanted
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: opacity > 0
                            opacity: current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            transform: Translate {
                                x: page.current ? 0 : (page.index < root.tab ? -24 : 24)
                                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            }
                            sourceComponent: page.modelData
                        }
                    }
                }
            }
        }
    }

    Component { id: translatorPage; Translator {} }
    Component { id: todoPage; TodoWidget {} }
    Component { id: aiPage; AiChat {} }

    IpcHandler {
        target: "sidebarLeft"
        function toggle(): void { GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen; }
        function close(): void { GlobalStates.sidebarLeftOpen = false; }
        function open(): void { GlobalStates.sidebarLeftOpen = true; }
        function tab(index: int): void { root.tab = index; GlobalStates.sidebarLeftOpen = true; }
    }
    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Abre e fecha a lateral esquerda"
        onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
    }
    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Abre a lateral esquerda"
        onPressed: GlobalStates.sidebarLeftOpen = true
    }
    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Fecha a lateral esquerda"
        onPressed: GlobalStates.sidebarLeftOpen = false
    }
    GlobalShortcut {
        name: "sidebarLeftToggleDetach"
        description: "Abre e fecha a lateral esquerda"
        onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
    }
}
