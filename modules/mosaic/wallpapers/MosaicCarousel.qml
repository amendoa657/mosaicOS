pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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

// The wallpaper carousel: a row of slanted cards (parallelograms) over the
// selected wallpaper, blurred and dimmed, filling the screen. The one in the
// middle is big and in front; the others shrink and fade with their distance.
// - Arrows or the wheel move, Enter (or a click on the middle card) applies,
//   typing filters by name, Tab changes the colour filter, Esc closes.
// - Applying hands the path to MosaicWalls, and MosaicWallFx brings it in with
//   the pixel colonies.
// - Smoothness: every slot has the same fixed width, so scrolling never lays
//   anything out again; each card only changes scale and opacity, worked out
//   from its distance to the middle.
// - Sharpness: each card shows the 480x300 thumbnail at once; the middle one and
//   its neighbours then fade in the original, decoded at the card's size.
// - Slant: a shear (Matrix4x4) on the card, which clips to the slanted shape;
//   the picture inside gets the opposite shear, so it stands straight.
// - Theme: thin glass edges (soft), a cream outline on a hard shadow (brutal),
//   film grain and serif names (retro).
// Same shortcuts and IPC as the old picker: wallpaperSelectorToggle/Random,
//   qs -c mosaic ipc call wallpaperSelector toggle|random
// Idea from pocket-dots' picker ("ilyamiro coverflow", diegoMalagrida/pocket-dots, GPL-3.0).
Scope {
    id: root

    readonly property bool open: GlobalStates.wallpaperSelectorOpen
    property string openScreen: ""
    onOpenChanged: {
        if (root.open) {
            root.openScreen = Hyprland.focusedMonitor?.name ?? "";
            MosaicWalls.refresh();
        }
    }
    MosaicSpring { id: openSpring; response: 0.4; damping: 0.82; springBack: false; closeMs: 220; target: root.open ? 1 : 0 }

    function toggle() { GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen; }

    IpcHandler {
        target: "wallpaperSelector"
        function toggle(): void { root.toggle(); }
        function open(): void { GlobalStates.wallpaperSelectorOpen = true; }
        function random(): void { MosaicWalls.random(); }
    }
    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Abre o carrossel de papéis de parede do Mosaic OS"
        onPressed: root.toggle()
    }
    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Papel de parede aleatório"
        onPressed: MosaicWalls.random()
    }

    LazyLoader {
        active: root.open || openSpring.value > 0.01
        component: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === root.openScreen) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mosaicCarousel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property real v: Math.max(0, openSpring.value)
            property string filter: "all"
            property string query: ""
            readonly property var shown: {
                const q = win.query.trim().toLowerCase();
                let list = win.filter === "recent" ? MosaicWalls.history.filter(p => MosaicWalls.files.includes(p)) : MosaicWalls.files;
                if (win.filter !== "all" && win.filter !== "recent")
                    list = list.filter(p => MosaicWalls.hueOf(MosaicWalls.toneOf(p)) === win.filter);
                if (q !== "")
                    list = list.filter(p => MosaicWalls.niceName(p).toLowerCase().includes(q));
                return list;
            }
            // Until you move, every new list (the folder is read again when it opens)
            // starts on the wallpaper in use. Done after the row has taken the list:
            // setting it before gets reset to 0.
            property bool touched: false
            onShownChanged: {
                if (win.touched || win.shown.length === 0)
                    return;
                Qt.callLater(() => {
                    row.currentIndex = Math.max(0, win.shown.indexOf(MosaicWalls.currentPath));
                    row.positionViewAtIndex(row.currentIndex, ListView.SnapPosition);
                });
            }
            readonly property string selected: row.currentIndex >= 0 && row.currentIndex < win.shown.length ? win.shown[row.currentIndex] : ""

            function apply(path) {
                if (!path)
                    return;
                GlobalStates.wallpaperSelectorOpen = false;
                MosaicWalls.apply(path);
            }
            function nextFilter(step) {
                win.touched = true;
                const ids = MosaicWalls.filters.map(f => f.id);
                win.filter = ids[(ids.indexOf(win.filter) + step + ids.length) % ids.length];
                row.currentIndex = 0;
            }

            // card size, from the screen
            readonly property real cardH: Math.round(win.height * 0.4)
            readonly property real cardW: Math.round(win.cardH * 1.55)
            readonly property real skew: -0.32
            readonly property real slotW: Math.round(win.cardW * 0.62)

            // ----- the immersive background: the selected wallpaper, blurred and dimmed -----
            // Two layers that take turns, so a new selection crossfades over the last.
            Item {
                id: backdrop
                anchors.fill: parent
                opacity: win.v
                property bool useB: false
                property string shownPath: ""
                Connections {
                    target: win
                    function onSelectedChanged() {
                        if (!win.selected || win.selected === backdrop.shownPath)
                            return;
                        backdrop.shownPath = win.selected;
                        backdrop.useB = !backdrop.useB;
                        (backdrop.useB ? bgB : bgA).source = MosaicWalls.thumbFor(win.selected);
                    }
                }
                Image {
                    id: bgA
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(480, 300)
                    visible: false
                }
                Image {
                    id: bgB
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(480, 300)
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: bgA
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    opacity: backdrop.useB ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 380 } }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: bgB
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    opacity: backdrop.useB ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 380 } }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: MosaicTheme.brutal ? 0.5 : 0.42
                }
                Grain { radius: 0; amount: MosaicTheme.grainPicker } // film grain (retro themes)
                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.wallpaperSelectorOpen = false
                    onWheel: wheel => {
                        win.touched = true;
                        if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0)
                            row.incrementCurrentIndex();
                        else
                            row.decrementCurrentIndex();
                    }
                }
            }

            // ----- the row of cards -----
            ListView {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -win.height * 0.03
                height: win.cardH * 1.25
                orientation: ListView.Horizontal
                model: win.shown
                interactive: false // the arrows and the wheel drive it
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - win.slotW / 2
                preferredHighlightEnd: width / 2 + win.slotW / 2
                highlightMoveDuration: 320
                cacheBuffer: win.slotW * 6
                opacity: win.v
                transform: Translate { y: (1 - win.v) * 40 }

                delegate: Item {
                    id: slot
                    required property string modelData
                    required property int index
                    width: win.slotW
                    height: row.height
                    // distance to the middle, in slots
                    readonly property real dist: Math.abs(slot.x - row.contentX + width / 2 - row.width / 2) / win.slotW
                    readonly property bool isSelected: ListView.isCurrentItem
                    readonly property bool inUse: modelData === MosaicWalls.currentPath
                    z: 100 - Math.round(dist * 10)

                    Item {
                        id: card
                        width: win.cardW
                        height: win.cardH
                        anchors.centerIn: parent
                        scale: Math.max(0.5, 1 - Math.min(slot.dist, 3) * 0.17)
                        opacity: Math.max(0, 1 - Math.min(slot.dist, 4) * 0.24)

                        // brutal themes: a hard shadow, slanted like the card
                        Rectangle {
                            visible: MosaicTheme.brutal
                            x: 10
                            y: 10
                            width: parent.width
                            height: parent.height
                            color: MosaicTheme.shadowColor
                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, win.skew, 0, -win.skew * win.cardH / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        }
                        // the slanted card: the shear makes its clip a parallelogram
                        Item {
                            anchors.fill: parent
                            clip: true
                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, win.skew, 0, -win.skew * win.cardH / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                            Rectangle {
                                anchors.fill: parent
                                color: Appearance.colors.colLayer1
                            }
                            // the picture, sheared back so it stands straight, wide enough to cover the corners.
                            // The 480 px thumbnail shows at once; the original, decoded at the card's own
                            // size (sharp, without decoding a 6K image at full size), fades in over it.
                            Item {
                                width: parent.width + win.cardH * Math.abs(win.skew) + 4
                                height: parent.height
                                x: -(win.cardH * Math.abs(win.skew) + 4) / 2
                                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -win.skew, 0, win.skew * win.cardH / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                                Image {
                                    anchors.fill: parent
                                    source: MosaicWalls.thumbFor(slot.modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(480, 300)
                                    visible: sharp.status !== Image.Ready
                                }
                                Image {
                                    id: sharp
                                    anchors.fill: parent
                                    // only the middle card and its neighbours: images are decoded one at a
                                    // time, and a dozen 6K originals queued the thumbnails behind them
                                    source: slot.dist < 1.6 ? "file://" + slot.modelData : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                    sourceSize: Qt.size(Math.ceil(parent.width), Math.ceil(parent.height))
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }
                                }
                            }
                            Grain { radius: 0; amount: MosaicTheme.grainPicker }
                            // the edge: thin glass (soft) or a thick cream line (brutal); the selected one in the accent
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: MosaicTheme.brutal ? 3 : slot.isSelected ? 2 : 1
                                border.color: MosaicTheme.brutal ? MosaicTheme.ink : slot.isSelected ? Appearance.colors.colPrimary : Qt.rgba(1, 1, 1, 0.3)
                            }
                        }
                        // the wallpaper in use gets a check
                        Rectangle {
                            visible: slot.inUse
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            width: 26
                            height: 26
                            radius: MosaicTheme.r(8)
                            color: Appearance.colors.colPrimary
                            border.width: MosaicTheme.brutal ? 2 : 0
                            border.color: MosaicTheme.ink
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 17
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                win.touched = true;
                                if (slot.isSelected)
                                    win.apply(slot.modelData);
                                else
                                    row.currentIndex = slot.index;
                            }
                        }
                    }
                }
            }

            // ----- under the row: the name, the search and the filters -----
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: row.bottom
                anchors.topMargin: 8
                spacing: 14
                opacity: win.v

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        radius: MosaicTheme.r(4)
                        color: MosaicWalls.toneOf(win.selected) || Appearance.colors.colLayer2
                        border.width: MosaicTheme.brutal ? 1.5 : 0
                        border.color: MosaicTheme.ink
                    }
                    StyledText {
                        text: win.selected ? MosaicWalls.niceName(win.selected) : (win.shown.length === 0 ? "nenhum papel" : "")
                        font.family: MosaicTheme.fontDisplay
                        font.pixelSize: 26
                        font.weight: MosaicTheme.retro ? Font.Normal : Font.DemiBold
                        color: "white"
                        style: Text.Raised
                        styleColor: "#55000000"
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${row.currentIndex + 1} / ${win.shown.length}`
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.65)
                    }
                }

                // search
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360
                    height: 42
                    radius: Appearance.rounding.small
                    color: MosaicTheme.brutal ? MosaicTheme.slabRaised : Qt.rgba(0, 0, 0, 0.35)
                    border.width: MosaicTheme.brutal ? MosaicTheme.border : 1
                    border.color: MosaicTheme.brutal ? MosaicTheme.ink : Qt.rgba(1, 1, 1, search.text !== "" ? 0.45 : 0.2)
                    HardShadow {}
                    MaterialSymbol {
                        id: searchIcon
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: 18
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        focus: root.open
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 14
                        color: MosaicTheme.brutal ? Appearance.colors.colOnLayer0 : "white"
                        selectionColor: Appearance.colors.colPrimary
                        clip: true
                        onTextChanged: {
                            win.touched = true;
                            win.query = text;
                            row.currentIndex = 0;
                        }
                        StyledText {
                            visible: search.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "digite para buscar"
                            font: search.font
                            color: MosaicTheme.brutal ? Appearance.colors.colSubtext : Qt.rgba(1, 1, 1, 0.5)
                        }
                        // the keyboard drives the carousel from here
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                GlobalStates.wallpaperSelectorOpen = false;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                win.apply(win.selected);
                            } else if (event.key === Qt.Key_Right) {
                                win.touched = true;
                                row.incrementCurrentIndex();
                            } else if (event.key === Qt.Key_Left) {
                                win.touched = true;
                                row.decrementCurrentIndex();
                            } else if (event.key === Qt.Key_Tab) {
                                win.nextFilter(1);
                            } else if (event.key === Qt.Key_Backtab) {
                                win.nextFilter(-1);
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }

                // filters: all, recent and the colour blocks, plus random
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Repeater {
                        model: MosaicWalls.filters
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool on: win.filter === modelData.id
                            width: modelData.label ? chipText.implicitWidth + 24 : 34
                            height: 34
                            radius: Appearance.rounding.small
                            color: MosaicTheme.brutal ? (on ? Appearance.colors.colPrimaryContainer : MosaicTheme.slabRaised)
                                : on ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.3)
                            border.width: MosaicTheme.brutal ? (on ? MosaicTheme.border : 1) : on ? 1 : 0
                            border.color: MosaicTheme.brutal ? MosaicTheme.ink : Qt.rgba(1, 1, 1, 0.5)
                            transform: Translate { x: chipShadow.sinkShift; y: chipShadow.sinkShift }
                            HardShadow { id: chipShadow; sink: chipArea.pressed || chip.on }
                            Behavior on color { ColorAnimation { duration: 160 } }
                            StyledText {
                                id: chipText
                                visible: !!chip.modelData.label
                                anchors.centerIn: parent
                                text: chip.modelData.label ?? ""
                                font.family: MosaicTheme.fontUi
                                font.pixelSize: 12
                                color: MosaicTheme.brutal ? Appearance.colors.colOnLayer0 : "white"
                            }
                            Rectangle {
                                visible: !chip.modelData.label
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                radius: MosaicTheme.r(4)
                                color: chip.modelData.color ?? "transparent"
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                onClicked: {
                                    win.touched = true;
                                    win.filter = chip.modelData.id;
                                    row.currentIndex = 0;
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: randomRow.implicitWidth + 24
                        height: 34
                        radius: Appearance.rounding.small
                        color: MosaicTheme.brutal ? MosaicTheme.slabRaised : Qt.rgba(0, 0, 0, 0.3)
                        border.width: MosaicTheme.brutal ? 1 : 0
                        border.color: MosaicTheme.ink
                        transform: Translate { x: randomShadow.sinkShift; y: randomShadow.sinkShift }
                        HardShadow { id: randomShadow; sink: randomArea.pressed }
                        Row {
                            id: randomRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: "shuffle"
                                iconSize: 16
                                color: MosaicTheme.brutal ? Appearance.colors.colOnLayer0 : "white"
                            }
                            StyledText {
                                text: "Aleatório"
                                font.family: MosaicTheme.fontUi
                                font.pixelSize: 12
                                color: MosaicTheme.brutal ? Appearance.colors.colOnLayer0 : "white"
                            }
                        }
                        MouseArea {
                            id: randomArea
                            anchors.fill: parent
                            onClicked: {
                                GlobalStates.wallpaperSelectorOpen = false;
                                MosaicWalls.random();
                            }
                        }
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "← → navegar · ↵ aplicar · tab cor · esc fechar"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
            }
        }
    }
}
