pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mosaic.island

// The Mosaic OS wallpaper picker, and the "pour" that applies a wallpaper.
// - Picker: a glass card with the folder's wallpapers in a grid, search, filters
//   (all, recent, by colour) and random. Arrows move, Enter applies, Tab changes
//   the filter, Esc closes. It replaces the ii selector (same shortcuts).
// - Pour: the chosen wallpaper spreads like liquid from where you clicked
//   (shaders/pour.frag), then the ii script applies it for real (Matugen
//   colours and all) and the liquid fades away.
// Layout and pour idea from hyprdots (fedyaqq34356/hyprdots, GPL-3.0), in the Mosaic style.
Scope {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/mosaic-os/wallpapers"
    readonly property string currentPath: Config.options.background.wallpaperPath
    readonly property string folder: {
        const p = root.currentPath;
        return p && p.indexOf("/") >= 0 ? p.substring(0, p.lastIndexOf("/")) : Directories.pictures + "/Wallpapers";
    }

    property var files: []    // full paths
    property var tones: ({})  // file name -> "#rrggbb"
    property var history: []  // full paths, newest first

    function baseName(p) { return p.substring(p.lastIndexOf("/") + 1); }
    function niceName(p) {
        const n = root.baseName(p);
        return n.substring(0, n.lastIndexOf(".") > 0 ? n.lastIndexOf(".") : n.length).replace(/[_-]+/g, " ");
    }
    function thumbFor(p) { return "file://" + root.cacheDir + "/thumbs/" + root.baseName(p) + ".jpg"; }

    // a colour's family, for the colour filter
    function hueOf(hex) {
        if (!hex)
            return "";
        const c = Qt.color(hex);
        if (c.hslSaturation < 0.18 || c.hslLightness < 0.12 || c.hslLightness > 0.92)
            return "gray";
        const h = c.hslHue * 360;
        if (h < 15 || h >= 335) return "red";
        if (h < 45) return "orange";
        if (h < 70) return "yellow";
        if (h < 170) return "green";
        if (h < 255) return "blue";
        if (h < 292) return "purple";
        return "pink";
    }
    readonly property var filters: [
        { id: "all", label: "Todos" }, { id: "recent", label: "Recentes" },
        { id: "red", color: "#e5534b" }, { id: "orange", color: "#ec8f3e" }, { id: "yellow", color: "#e3c449" },
        { id: "green", color: "#57ab5a" }, { id: "blue", color: "#539bf5" }, { id: "purple", color: "#986ee2" },
        { id: "pink", color: "#e26d9f" }, { id: "gray", color: "#8b8b8b" }
    ]

    // ---------- reading the folder ----------
    Process {
        id: lister
        command: ["sh", "-c", `find '${root.folder}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = this.text.split("\n").filter(l => l.trim() !== "");
                indexer.running = true;
            }
        }
    }
    // thumbnails and colours, only for new images (scripts/wallpaper-index.sh)
    Process {
        id: indexer
        command: [Quickshell.shellPath("scripts/wallpaper-index.sh"), root.folder]
        onExited: toneFile.reload()
    }
    FileView {
        id: toneFile
        path: root.cacheDir + "/colors.tsv"
        onLoaded: {
            const map = {};
            for (const line of toneFile.text().split("\n")) {
                const parts = line.split("\t");
                if (parts.length === 2 && parts[0] !== "")
                    map[parts[0]] = parts[1].trim();
            }
            root.tones = map;
        }
    }
    FileView {
        id: historyFile
        path: root.cacheDir + "/history"
        printErrors: false // it only exists after the first wallpaper is applied
        onLoaded: {
            const seen = {};
            const out = [];
            const lines = historyFile.text().split("\n");
            for (let i = lines.length - 1; i >= 0; i--) {
                const p = lines[i].trim();
                if (p !== "" && !seen[p]) {
                    seen[p] = true;
                    out.push(p);
                }
            }
            root.history = out;
        }
    }

    // ---------- open / close ----------
    property string openScreen: ""
    property string startPage: "papers" // which tab it opens on (the IPC can ask for widgets)
    readonly property bool open: GlobalStates.wallpaperSelectorOpen
    onOpenChanged: {
        if (root.open) {
            root.openScreen = Hyprland.focusedMonitor?.name ?? "";
            lister.running = true;
            historyFile.reload();
        }
    }
    // the card opens on a spring and closes with a quick slide
    MosaicSpring { id: openSpring; response: 0.42; damping: 0.78; springBack: false; closeMs: 200; target: root.open ? 1 : 0 }

    function toggle() { GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen; }
    function randomPour() {
        const pool = root.files.filter(f => f !== root.currentPath);
        if (pool.length === 0)
            return;
        const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        root.pour(pool[Math.floor(Math.random() * pool.length)], screen.name, screen.width / 2, screen.height / 2);
    }

    IpcHandler {
        target: "wallpaperSelector"
        function toggle(): void { root.toggle(); }
        function widgets(): void { root.startPage = "widgets"; GlobalStates.wallpaperSelectorOpen = true; }
        function random(): void {
            if (root.files.length === 0) {
                lister.running = true;
                randomLater.start();
            } else {
                root.randomPour();
            }
        }
    }
    Timer { id: randomLater; interval: 400; onTriggered: root.randomPour() }
    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Abre o seletor de papéis de parede do Mosaic OS"
        onPressed: root.toggle()
    }
    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Papel de parede aleatório (derramando)"
        onPressed: {
            if (root.files.length === 0) {
                lister.running = true;
                randomLater.start();
            } else {
                root.randomPour();
            }
        }
    }

    // ---------- the picker window ----------
    LazyLoader {
        active: root.open || openSpring.value > 0.01
        component: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === root.openScreen) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mosaicWallpapers"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property real v: Math.max(0, openSpring.value)
            property string filter: "all"
            property string page: root.startPage // "papers" | "widgets" (the tabs at the top)
            Component.onDestruction: root.startPage = "papers"
            property string query: ""
            readonly property var shown: {
                const q = win.query.trim().toLowerCase();
                let list = win.filter === "recent" ? root.history.filter(p => root.files.includes(p)) : root.files;
                if (win.filter !== "all" && win.filter !== "recent")
                    list = list.filter(p => root.hueOf(root.tones[root.baseName(p)]) === win.filter);
                if (q !== "")
                    list = list.filter(p => root.niceName(p).toLowerCase().includes(q));
                return list;
            }
            // the first time the list fills, start on the wallpaper in use
            property bool positioned: false
            onShownChanged: {
                if (!win.positioned && win.shown.length > 0) {
                    win.positioned = true;
                    grid.currentIndex = Math.max(0, win.shown.indexOf(root.currentPath));
                }
            }
            readonly property string selected: grid.currentIndex >= 0 && grid.currentIndex < win.shown.length ? win.shown[grid.currentIndex] : root.currentPath

            function apply(path, item) {
                const pt = item ? item.mapToItem(null, item.width / 2, item.height / 2) : Qt.point(win.width / 2, win.height / 2);
                GlobalStates.wallpaperSelectorOpen = false;
                root.pour(path, win.screen.name, pt.x, pt.y);
            }
            function nextFilter(step) {
                const ids = root.filters.map(f => f.id);
                win.filter = ids[(ids.indexOf(win.filter) + step + ids.length) % ids.length];
            }

            // the dim behind the card (kept under the glass threshold, so only the card is glass)
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.25 * win.v
                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.wallpaperSelectorOpen = false
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(1120, win.width - 80)
                height: Math.min(680, win.height - 100)
                radius: Appearance.rounding.large
                color: MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer0
                border.width: MosaicTheme.brutal ? MosaicTheme.border : 1
                border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
                opacity: win.v
                // brutal themes: a big hard shadow under the whole card
                Rectangle {
                    visible: MosaicTheme.brutal
                    z: -1
                    x: 8
                    y: 8
                    width: parent.width
                    height: parent.height
                    radius: parent.radius
                    color: MosaicTheme.shadowColor
                }
                scale: 0.94 + 0.06 * win.v
                MouseArea { anchors.fill: parent } // clicks on the card don't close it

                // ----- left column -----
                ColumnLayout {
                    id: side
                    x: 24
                    y: 24
                    width: 290
                    height: parent.height - 48
                    spacing: 14

                    RowLayout {
                        spacing: 10
                        Mascot {
                            size: 18
                            showFace: false
                        }
                        StyledText {
                            text: MosaicTheme.brutal ? "PAPÉIS DE PAREDE" : "Papéis de parede"
                            font.letterSpacing: MosaicTheme.brutal ? 1.2 : 0
                            font.family: "Space Grotesk"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                        Rectangle {
                            implicitWidth: countText.implicitWidth + 12
                            implicitHeight: 20
                            radius: MosaicTheme.r(6)
                            // brutal themes: a tilted sticker
                            color: MosaicTheme.brutal ? Appearance.colors.colTertiaryContainer : Appearance.colors.colLayer1
                            rotation: MosaicTheme.tilt * 1.6
                            border.width: MosaicTheme.brutal ? 1.5 : 0
                            border.color: MosaicTheme.ink
                            StyledText {
                                id: countText
                                anchors.centerIn: parent
                                text: `${win.shown.length} / ${root.files.length}`
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    // ----- themes: Mosaic (wallpaper colours) or a fixed palette -----
                    Row {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 8
                        Repeater {
                            model: MosaicTheme.themes
                            delegate: Rectangle {
                                id: themeCard
                                required property var modelData
                                readonly property bool on: MosaicTheme.current === modelData.id
                                // the Mosaic theme shows the live wallpaper tones
                                readonly property var swatches: modelData.swatches ?? [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colOnLayer0]
                                width: (side.width - 8) / 2
                                height: 56
                                radius: Appearance.rounding.small
                                color: modelData.base ?? Appearance.colors.colLayer1
                                border.width: on ? 2 : 1
                                border.color: MosaicTheme.brutal ? MosaicTheme.ink : on ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                                HardShadow { visible: MosaicTheme.brutal && themeCard.on }
                                scale: themeArea.pressed ? 0.95 : themeArea.containsMouse ? 1.02 : 1
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                // a little Mosaic mark painted in the theme's four tones
                                Item {
                                    id: miniMark
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    height: 26
                                    Repeater {
                                        model: [[0, 0, 56, 56], [64, 0, 24, 56], [0, 64, 56, 24], [64, 64, 24, 24]]
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            x: modelData[0] * 26 / 88
                                            y: modelData[1] * 26 / 88
                                            width: modelData[2] * 26 / 88
                                            height: modelData[3] * 26 / 88
                                            radius: MosaicTheme.r(2)
                                            color: themeCard.swatches[index]
                                        }
                                    }
                                }
                                Column {
                                    anchors.left: miniMark.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    StyledText {
                                        text: themeCard.modelData.name
                                        font.family: "Space Grotesk"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: themeCard.modelData.swatches ? themeCard.modelData.swatches[3] : Appearance.colors.colOnLayer0
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: themeCard.modelData.hint
                                        font.pixelSize: 10
                                        color: themeCard.modelData.swatches ? themeCard.modelData.swatches[3] : Appearance.colors.colOnLayer0
                                        opacity: 0.65
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    id: themeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: MosaicTheme.set(themeCard.modelData.id)
                                }
                            }
                        }
                    }

                    // the selected one: its name and its colour
                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        text: root.niceName(win.selected)
                        font.family: "Space Grotesk"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer0
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            implicitWidth: 14
                            implicitHeight: 14
                            radius: MosaicTheme.r(4)
                            color: root.tones[root.baseName(win.selected)] ?? Appearance.colors.colLayer2
                        }
                        StyledText {
                            text: (root.tones[root.baseName(win.selected)] ?? "").toUpperCase()
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        implicitHeight: 44
                        radius: Appearance.rounding.small
                        color: MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1
                        border.width: MosaicTheme.brutal ? MosaicTheme.border : search.activeFocus ? 2 : 1
                        border.color: MosaicTheme.brutal ? MosaicTheme.ink : search.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        HardShadow {}
                        MaterialSymbol {
                            id: searchIcon
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }
                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            focus: true
                            font.family: "Space Grotesk"
                            font.pixelSize: 14
                            color: Appearance.colors.colOnLayer0
                            selectionColor: Appearance.colors.colPrimary
                            clip: true
                            onTextChanged: {
                                win.query = text;
                                grid.currentIndex = 0;
                            }
                            StyledText {
                                visible: search.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "buscar"
                                font: search.font
                                color: Appearance.colors.colSubtext
                            }
                            // the keyboard drives the grid from here
                            Keys.onPressed: event => {
                                const cols = grid.columns;
                                if (event.key === Qt.Key_Escape) {
                                    GlobalStates.wallpaperSelectorOpen = false;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (win.shown.length > 0)
                                        win.apply(win.selected, grid.currentItem);
                                } else if (event.key === Qt.Key_Tab) {
                                    win.nextFilter(1);
                                } else if (event.key === Qt.Key_Backtab) {
                                    win.nextFilter(-1);
                                } else if (event.key === Qt.Key_Down) {
                                    grid.currentIndex = Math.min(win.shown.length - 1, grid.currentIndex + cols);
                                } else if (event.key === Qt.Key_Up) {
                                    grid.currentIndex = Math.max(0, grid.currentIndex - cols);
                                } else if (event.key === Qt.Key_Right && search.text === "") {
                                    grid.currentIndex = Math.min(win.shown.length - 1, grid.currentIndex + 1);
                                } else if (event.key === Qt.Key_Left && search.text === "") {
                                    grid.currentIndex = Math.max(0, grid.currentIndex - 1);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    // filters: all, recent and the colour dots
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: root.filters
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool on: win.filter === modelData.id
                                width: modelData.label ? chipText.implicitWidth + 24 : 34
                                height: 34
                                radius: Appearance.rounding.small
                                color: MosaicTheme.brutal ? (on ? Appearance.colors.colPrimaryContainer : MosaicTheme.slabRaised) : on ? root.softBlockOf(Appearance.colors.colPrimary) : Appearance.colors.colLayer1
                                border.width: MosaicTheme.brutal ? (on ? MosaicTheme.border : 1) : on ? 1 : 0
                                border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colPrimary
                                transform: Translate { x: filterShadow.sinkShift; y: filterShadow.sinkShift }
                                HardShadow { id: filterShadow; sink: chipArea.pressed || chip.on }
                                scale: !MosaicTheme.brutal && chipArea.pressed ? 0.92 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 160 } }
                                StyledText {
                                    id: chipText
                                    visible: !!chip.modelData.label
                                    anchors.centerIn: parent
                                    text: chip.modelData.label ?? ""
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 12
                                    color: Appearance.colors.colOnLayer0
                                }
                                Rectangle {
                                    visible: !chip.modelData.label
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    radius: MosaicTheme.r(4) // a little Mosaic block
                                    color: chip.modelData.color ?? "transparent"
                                }
                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    onClicked: {
                                        win.filter = chip.modelData.id;
                                        grid.currentIndex = 0;
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PickerButton {
                            Layout.fillWidth: true
                            icon: "format_paint"
                            label: "Aplicar"
                            strong: true
                            onClicked: if (win.shown.length > 0) win.apply(win.selected, grid.currentItem)
                        }
                        PickerButton {
                            icon: "shuffle"
                            label: "Aleatório"
                            onClicked: {
                                GlobalStates.wallpaperSelectorOpen = false;
                                root.randomPour();
                            }
                        }
                    }
                    StyledText {
                        text: "tab filtro · ↵ aplicar · esc fechar"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        color: Appearance.colors.colSubtext
                    }
                }

                // ----- tabs: Papéis / Widgets -----
                Row {
                    id: pageTabs
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    spacing: 8
                    Repeater {
                        model: [{ id: "papers", label: "Papéis", icon: "wallpaper" }, { id: "widgets", label: "Widgets", icon: "widgets" }]
                        delegate: Rectangle {
                            id: pageTab
                            required property var modelData
                            readonly property bool on: win.page === modelData.id
                            implicitWidth: pageTabRow.implicitWidth + 28
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : root.softBlockOf(Appearance.colors.colPrimary))
                                : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1)
                            border.width: MosaicTheme.brutal ? (on ? MosaicTheme.border : 1) : 0
                            border.color: MosaicTheme.ink
                            Behavior on color { ColorAnimation { duration: 160 } }
                            transform: Translate { x: tabShadow.sinkShift; y: tabShadow.sinkShift }
                            HardShadow { id: tabShadow; visible: MosaicTheme.brutal && !pageTab.on; sink: pageTabArea.pressed }
                            RowLayout {
                                id: pageTabRow
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol {
                                    text: pageTab.modelData.icon
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    text: MosaicTheme.brutal ? pageTab.modelData.label.toUpperCase() : pageTab.modelData.label
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 14
                                    font.weight: pageTab.on ? Font.Bold : Font.Normal
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                            MouseArea {
                                id: pageTabArea
                                anchors.fill: parent
                                onClicked: win.page = pageTab.modelData.id
                            }
                        }
                    }
                }

                // ----- Widgets: the desktop widgets, each with its own switch -----
                // Each one is Config.options.background.widgets.<key>.enable: the ii
                // background shows or hides it as soon as the value changes.
                GridView {
                    id: widgetGrid
                    visible: win.page === "widgets"
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    clip: true
                    cellWidth: Math.floor(width / 2)
                    cellHeight: 92
                    interactive: false
                    model: [
                        { key: "clock", icon: "schedule", name: "Relógio", hint: "a hora grande no fundo" },
                        { key: "calendar", icon: "calendar_month", name: "Calendário", hint: "o mês com o dia de hoje" },
                        { key: "weather", icon: "partly_cloudy_day", name: "Clima", hint: "temperatura e previsão" },
                        { key: "media", icon: "music_note", name: "Música", hint: "o que está tocando" },
                        { key: "photos", icon: "photo", name: "Fotos", hint: "um porta-retratos" },
                        { key: "photos2", icon: "photo_library", name: "Fotos 2", hint: "o segundo porta-retratos" },
                        { key: "anniversary", icon: "favorite", name: "Dias juntos", hint: "o contador de dias" }
                    ]
                    delegate: Item {
                        id: wcell
                        required property var modelData
                        required property int index
                        readonly property var conf: Config.options.background.widgets[modelData.key]
                        readonly property bool on: conf?.enable ?? false
                        width: widgetGrid.cellWidth
                        height: widgetGrid.cellHeight
                        // cascade, like the wallpapers
                        property real born: 0
                        Behavior on born { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                        Timer { running: wcell.visible; interval: 60 + wcell.index * 40; onTriggered: wcell.born = 1 }
                        onVisibleChanged: if (!visible) born = 0

                        Rectangle {
                            id: wcard
                            anchors.fill: parent
                            anchors.margins: 6
                            anchors.rightMargin: 6 + MosaicTheme.shadow
                            anchors.bottomMargin: 6 + MosaicTheme.shadow
                            radius: Appearance.rounding.normal
                            opacity: wcell.born
                            scale: 0.9 + 0.1 * wcell.born
                            color: MosaicTheme.brutal ? (wcell.on ? MosaicTheme.slabRaised : MosaicTheme.slab) : (wcell.on ? root.softBlockOf(Appearance.colors.colPrimary) : Appearance.colors.colLayer1)
                            border.width: MosaicTheme.brutal ? MosaicTheme.border : 0
                            border.color: MosaicTheme.ink
                            Behavior on color { ColorAnimation { duration: 200 } }
                            transform: Translate { x: wShadow.sinkShift; y: wShadow.sinkShift }
                            HardShadow { id: wShadow; visible: MosaicTheme.brutal && wcell.on; sink: wArea.pressed }

                            Rectangle { // the icon on a little block
                                id: wIcon
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 44
                                radius: Appearance.rounding.small
                                color: wcell.on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : Appearance.colors.colPrimary) : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer2)
                                border.width: MosaicTheme.brutal ? 1.5 : 0
                                border.color: MosaicTheme.ink
                                Behavior on color { ColorAnimation { duration: 200 } }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: wcell.modelData.icon
                                    iconSize: 24
                                    fill: wcell.on ? 1 : 0
                                    color: wcell.on && !MosaicTheme.brutal ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                }
                            }
                            Column {
                                anchors.left: wIcon.right
                                anchors.leftMargin: 12
                                anchors.right: wSwitch.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                StyledText {
                                    width: parent.width
                                    text: wcell.modelData.name
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    width: parent.width
                                    text: wcell.modelData.hint
                                    font.pixelSize: 11
                                    color: Appearance.colors.colOnLayer0
                                    opacity: 0.65
                                    elide: Text.ElideRight
                                }
                            }
                            // the switch: the knob slides on a spring (square knob in brutal themes)
                            Rectangle {
                                id: wSwitch
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46
                                height: 26
                                radius: MosaicTheme.r(13)
                                color: wcell.on ? Appearance.colors.colPrimary : (MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer2)
                                border.width: MosaicTheme.brutal ? 1.5 : 0
                                border.color: MosaicTheme.ink
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: MosaicTheme.r(9)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 4 + (parent.width - width - 8) * knob.value
                                    color: wcell.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                    MosaicSpring { id: knob; response: 0.3; damping: 0.7; epsilon: 0.002; target: wcell.on ? 1 : 0; Component.onCompleted: settle(target) }
                                }
                            }
                            MouseArea {
                                id: wArea
                                anchors.fill: parent
                                onClicked: if (wcell.conf) wcell.conf.enable = !wcell.on
                            }
                        }
                    }
                }

                // ----- the grid -----
                GridView {
                    id: grid
                    visible: win.page === "papers"
                    readonly property int columns: 3
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    clip: true
                    cellWidth: Math.floor(width / columns)
                    cellHeight: Math.round(cellWidth * 0.62)
                    model: win.shown
                    currentIndex: 0
                    highlightFollowsCurrentItem: false
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: cellHeight * 2
                    onCurrentIndexChanged: grid.positionViewAtIndex(currentIndex, GridView.Contain)

                    delegate: Item {
                        id: cell
                        required property string modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        readonly property bool isCurrent: modelData === root.currentPath
                        readonly property bool selected: GridView.isCurrentItem

                        // cascade: each tile comes in a moment after the one before
                        property real born: 0
                        Behavior on born { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                        Timer {
                            running: true
                            interval: 60 + Math.min(cell.index, 12) * 28
                            onTriggered: cell.born = 1
                        }
                        MosaicSpring { id: lift; response: 0.36; damping: 0.7; epsilon: 0.002; target: tileArea.containsMouse || cell.selected ? 1 : 0 }

                        Item {
                            id: tile
                            anchors.fill: parent
                            anchors.margins: 7
                            opacity: cell.born
                            scale: (0.86 + 0.14 * cell.born) * (1 + 0.035 * lift.value)
                            transform: Translate { y: (1 - cell.born) * 18 }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colLayer1
                                Image {
                                    anchors.fill: parent
                                    source: root.thumbFor(cell.modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(480, 300)
                                }
                                // the name, over a soft shade, on hover or selection
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 36
                                    opacity: lift.value
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: "transparent" }
                                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                                    }
                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        text: root.niceName(cell.modelData)
                                        font.family: "Space Grotesk"
                                        font.pixelSize: 11
                                        color: "white"
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            // selection outline in the accent (brutal themes: a cream frame on a hard shadow)
                            Rectangle {
                                z: -1
                                visible: MosaicTheme.brutal
                                x: MosaicTheme.shadow + 2
                                y: MosaicTheme.shadow + 2
                                width: parent.width
                                height: parent.height
                                radius: Appearance.rounding.normal
                                color: MosaicTheme.shadowColor
                                opacity: cell.selected ? 1 : 0
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                color: "transparent"
                                border.width: MosaicTheme.brutal ? 3 : 2
                                border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colPrimary
                                opacity: cell.selected ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            // the wallpaper in use gets a check
                            Rectangle {
                                visible: cell.isCurrent
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                width: 22
                                height: 22
                                radius: MosaicTheme.r(7)
                                color: Appearance.colors.colPrimary
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: 15
                                    color: Appearance.colors.colOnPrimary
                                }
                            }
                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: grid.currentIndex = cell.index
                                onClicked: win.apply(cell.modelData, tile)
                            }
                        }
                    }
                }
            }
        }
    }

    function softBlockOf(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.32); }

    component PickerButton: Rectangle {
        id: btn
        required property string icon
        required property string label
        property bool strong: false
        signal clicked()
        implicitWidth: btnRow.implicitWidth + 28
        implicitHeight: 44
        radius: Appearance.rounding.small
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: btn.strong ? ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.32) : Appearance.colors.colLayer1 }
            GradientStop { position: 1; color: btn.strong ? ColorUtils.mix(Appearance.colors.colSecondary, Appearance.colors.colLayer1, 0.32) : Appearance.colors.colLayer1 }
        }
        // brutal themes: it sinks into its shadow instead of shrinking
        border.width: MosaicTheme.border
        border.color: MosaicTheme.ink
        transform: Translate { x: btnShadow.sinkShift; y: btnShadow.sinkShift }
        HardShadow { id: btnShadow; sink: btnArea.pressed }
        scale: MosaicTheme.brutal ? 1 : btnArea.pressed ? 0.95 : btnArea.containsMouse ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: 8
            MaterialSymbol {
                text: btn.icon
                iconSize: 18
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                text: btn.label
                font.family: "Space Grotesk"
                font.pixelSize: 14
                font.weight: btn.strong ? Font.DemiBold : Font.Normal
                color: Appearance.colors.colOnLayer0
            }
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }

    // ---------- the pour ----------
    property string pourPath: ""
    property string pourScreen: ""
    property point pourPoint: Qt.point(0, 0)
    property real pourProgress: 0
    property real pourFade: 1
    readonly property bool pouring: root.pourPath !== ""

    function pour(path, screenName, x, y) {
        if (!path)
            return;
        pourRun.stop();
        fadeOut.stop();
        root.pourProgress = 0;
        root.pourFade = 1;
        root.pourScreen = screenName;
        root.pourPoint = Qt.point(x, y);
        root.pourPath = path;
        pourGuard.restart();
    }
    // the liquid only starts once the image is loaded; if it never loads, apply anyway
    function pourImageReady() {
        if (root.pouring && !pourRun.running && root.pourProgress === 0) {
            pourGuard.stop();
            pourRun.start();
        }
    }
    Timer {
        id: pourGuard
        interval: 2500
        onTriggered: if (root.pouring && root.pourProgress === 0) root.commit()
    }
    NumberAnimation {
        id: pourRun
        target: root
        property: "pourProgress"
        from: 0
        to: 1
        duration: 1700
        easing.type: Easing.Linear // the shader eases it
        onFinished: root.commit()
    }
    // the real change: the ii script (wallpaper + Matugen colours), and a line in the history
    function commit() {
        Wallpapers.select(root.pourPath);
        historyWriter.command = ["sh", "-c", `mkdir -p '${root.cacheDir}' && printf '%s\\n' "$1" >> '${root.cacheDir}/history'`, "sh", root.pourPath];
        historyWriter.running = true;
        settleGuard.restart();
    }
    Process { id: historyWriter }
    // once the background shows the new picture (plus a moment to load it), the liquid fades
    Connections {
        target: Config.options.background
        function onWallpaperPathChanged() {
            if (root.pouring && Config.options.background.wallpaperPath === root.pourPath)
                settleDelay.restart();
        }
    }
    Timer { id: settleDelay; interval: 900; onTriggered: fadeOut.start() }
    Timer { id: settleGuard; interval: 8000; onTriggered: if (root.pouring) fadeOut.start() }
    NumberAnimation {
        id: fadeOut
        target: root
        property: "pourFade"
        to: 0
        duration: 320
        onFinished: {
            settleGuard.stop();
            root.pourPath = "";
            root.pourProgress = 0;
        }
    }

    Variants {
        model: root.pouring ? Quickshell.screens : []
        delegate: PanelWindow {
            id: pourWin
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mosaicPour"
            WlrLayershell.layer: WlrLayer.Bottom // over the wallpaper, under the windows
            mask: Region {} // clicks go through

            Image {
                id: pic
                visible: false
                source: root.pourPath ? "file://" + root.pourPath : ""
                asynchronous: true
                sourceSize: Qt.size(pourWin.width, pourWin.height)
                onStatusChanged: if (status === Image.Ready) root.pourImageReady()
            }
            ShaderEffect {
                anchors.fill: parent
                visible: pic.status === Image.Ready
                fragmentShader: Qt.resolvedUrl("shaders/pour.frag.qsb")
                property var source: pic
                property vector2d size: Qt.vector2d(width, height)
                property vector2d picSize: Qt.vector2d(Math.max(1, pic.implicitWidth), Math.max(1, pic.implicitHeight))
                // the liquid starts where you clicked on that screen; on the others, from the top middle
                property vector2d sink: pourWin.screen.name === root.pourScreen ? Qt.vector2d(root.pourPoint.x, root.pourPoint.y) : Qt.vector2d(width / 2, 0)
                property real progress: root.pourProgress
                property color tone: Appearance.colors.colPrimary
                opacity: root.pourFade
            }
        }
    }
}
