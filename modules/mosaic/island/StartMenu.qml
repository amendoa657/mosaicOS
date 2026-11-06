pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions

// The start menu, inside the card that drops out of the island when Super is
// tapped. All the searching is the ii's LauncherSearch service, so every ii
// feature is here: apps, math (=), shell commands ($), web search (?),
// clipboard (;), emojis (:) and actions (/). Empty, it shows the shortcuts for
// those prefixes and the recent apps.
// Keys: type to search, Up/Down choose, Enter runs, Esc closes.
Item {
    id: menu
    property var recents: null // RecentApps
    signal done()

    readonly property bool searching: LauncherSearch.query !== ""
    readonly property int rowHeight: 52
    readonly property int maxRows: 7
    readonly property var prefixes: Config.options.search.prefix
    readonly property var recentEntries: (menu.recents?.ids ?? []).map(id => DesktopEntries.heuristicLookup(id)).filter(e => !!e).slice(0, 8)

    implicitHeight: searchBox.height + 12 + (searching
        ? Math.min(list.count, maxRows) * rowHeight + (list.count === 0 ? 44 : 0)
        : chips.implicitHeight + 14 + (recentEntries.length > 0 ? recentTitle.height + 8 + recentGrid.implicitHeight : 0)) + 8

    function focusSearch() {
        search.text = LauncherSearch.query; // a shortcut may have set a prefix (clipboard, emojis)
        search.cursorPosition = search.text.length;
        search.forceActiveFocus();
    }
    function run(result) {
        if (!result)
            return;
        if (result.type === Translation.tr("App") && result.id)
            menu.recents?.add(result.id);
        result.execute();
        menu.done();
    }

    // the query can also change from outside (Super+V, Super+., the IPC)
    Connections {
        target: LauncherSearch
        function onQueryChanged() {
            if (search.text !== LauncherSearch.query)
                search.text = LauncherSearch.query;
        }
    }

    // ---------- search box ----------
    Rectangle {
        id: searchBox
        width: parent.width
        height: 48
        radius: MosaicTheme.r(16)
        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.93)
        border.width: 1
        border.color: search.activeFocus ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.4) : "transparent"
        MaterialSymbol {
            id: searchIcon
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            iconSize: 20
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }
        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Space Grotesk"
            font.pixelSize: 16
            color: Appearance.colors.colOnLayer0
            selectionColor: Appearance.colors.colPrimary
            clip: true
            onTextChanged: {
                LauncherSearch.query = text;
                list.currentIndex = 0;
            }
            StyledText {
                visible: search.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar apps, contas, comandos…"
                font: search.font
                color: Appearance.colors.colOnLayer0
                opacity: 0.45
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    menu.done();
                } else if (event.key === Qt.Key_Down) {
                    list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                } else if (event.key === Qt.Key_Up) {
                    list.currentIndex = Math.max(0, list.currentIndex - 1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (menu.searching)
                        menu.run(LauncherSearch.results[Math.max(0, list.currentIndex)]);
                    else if (menu.recentEntries.length > 0) {
                        menu.recents?.add(menu.recentEntries[0].id);
                        menu.recentEntries[0].execute();
                        menu.done();
                    }
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }

    // ---------- empty: the prefixes and the recent apps ----------
    Item {
        id: idle
        anchors.top: searchBox.bottom
        anchors.topMargin: 12
        width: parent.width
        visible: !menu.searching
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        // one chip per ii prefix: a click types it
        Flow {
            id: chips
            width: parent.width
            spacing: 6
            Repeater {
                model: [
                    { p: menu.prefixes.app, icon: "apps", label: "apps" },
                    { p: menu.prefixes.math, icon: "calculate", label: "conta" },
                    { p: menu.prefixes.shellCommand, icon: "terminal", label: "comando" },
                    { p: menu.prefixes.webSearch, icon: "travel_explore", label: "web" },
                    { p: menu.prefixes.clipboard, icon: "content_paste", label: "copiados" },
                    { p: menu.prefixes.emojis, icon: "mood", label: "emoji" },
                    { p: menu.prefixes.action, icon: "settings_suggest", label: "ações" }
                ]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    implicitWidth: chipRow.implicitWidth + 18
                    implicitHeight: 30
                    radius: MosaicTheme.r(10)
                    color: chipArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.86) : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.94)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    // they pop in one after the other
                    property real born: 0
                    Behavior on born { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                    Timer { running: true; interval: 80 + chip.index * 30; onTriggered: chip.born = 1 }
                    opacity: born
                    scale: 0.8 + 0.2 * born
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5
                        StyledText {
                            text: chip.modelData.p
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Appearance.colors.colPrimary
                        }
                        MaterialSymbol {
                            text: chip.modelData.icon
                            iconSize: 15
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                        StyledText {
                            text: chip.modelData.label
                            font.family: "Space Grotesk"
                            font.pixelSize: 12
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.85
                        }
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            search.text = chip.modelData.p;
                            search.forceActiveFocus();
                        }
                    }
                }
            }
        }

        StyledText {
            id: recentTitle
            visible: menu.recentEntries.length > 0
            anchors.top: chips.bottom
            anchors.topMargin: 14
            x: 4
            text: "Recentes"
            font.family: "Space Grotesk"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
        }
        Grid {
            id: recentGrid
            anchors.top: recentTitle.bottom
            anchors.topMargin: 8
            width: parent.width
            columns: 4
            Repeater {
                model: menu.recentEntries
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    width: recentGrid.width / 4
                    height: 84
                    property real born: 0
                    Behavior on born { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                    Timer { running: true; interval: 120 + tile.index * 35; onTriggered: tile.born = 1 }
                    MosaicSpring { id: hov; response: 0.32; damping: 0.7; epsilon: 0.002; target: tileArea.containsMouse ? 1 : 0 }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: MosaicTheme.r(14)
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 1 - 0.08 * hov.value)
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        opacity: tile.born
                        scale: (0.85 + 0.15 * tile.born) * (1 + 0.06 * hov.value)
                        transform: Translate { y: (1 - tile.born) * 10 - 2 * hov.value }
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 38
                            source: Quickshell.iconPath(AppSearch.guessIcon(tile.modelData.icon || tile.modelData.id), "image-missing")
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tile.width - 12
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            font.family: "Space Grotesk"
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.recents?.add(tile.modelData.id);
                            tile.modelData.execute();
                            menu.done();
                        }
                    }
                }
            }
        }
    }

    // ---------- results ----------
    StyledText {
        visible: menu.searching && list.count === 0
        anchors.top: searchBox.bottom
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Nada encontrado"
        font.family: "Space Grotesk"
        font.pixelSize: 13
        color: Appearance.colors.colOnLayer0
        opacity: 0.5
    }
    ListView {
        id: list
        anchors.top: searchBox.bottom
        anchors.topMargin: 12
        width: parent.width
        height: Math.min(count, menu.maxRows) * menu.rowHeight
        visible: menu.searching
        clip: true
        model: LauncherSearch.results
        currentIndex: 0
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        // the selection: a soft block that glides to the chosen row on a spring
        highlight: Item {}
        Rectangle {
            id: selection
            parent: list.contentItem
            width: list.width
            height: menu.rowHeight - 4
            radius: MosaicTheme.r(14)
            visible: list.count > 0
            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78)
            y: selSpring.value + 2
            MosaicSpring { id: selSpring; response: 0.26; damping: 0.82; epsilon: 0.3; target: Math.max(0, list.currentIndex) * menu.rowHeight }
        }
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool chosen: ListView.isCurrentItem
            readonly property bool isImage: modelData.rawValue !== "" && Cliphist.entryIsImage(modelData.rawValue)
            width: list.width
            height: menu.rowHeight
            // rows slide in a little, one after the other
            property real born: 0
            Behavior on born { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Timer { running: true; interval: Math.min(row.index, 8) * 22; onTriggered: row.born = 1 }
            opacity: born
            transform: Translate { x: (1 - row.born) * 14 }

            Item { // the icon: a system icon, a Material symbol or text (emoji)
                id: iconBox
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                IconImage {
                    anchors.centerIn: parent
                    visible: row.modelData.iconType === LauncherSearchResult.IconType.System
                    implicitSize: 30
                    source: visible ? Quickshell.iconPath(AppSearch.guessIcon(row.modelData.iconName), "image-missing") : ""
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: row.modelData.iconType === LauncherSearchResult.IconType.Material
                    text: row.modelData.iconName
                    iconSize: 22
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: row.modelData.iconType === LauncherSearchResult.IconType.Text
                    text: row.modelData.iconName
                    font.pixelSize: 22
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: row.modelData.iconType === LauncherSearchResult.IconType.None
                    text: row.isImage ? "image" : "content_paste"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
            }
            ColumnLayout {
                anchors.left: iconBox.right
                anchors.leftMargin: 12
                anchors.right: tail.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    font.family: row.modelData.fontType === LauncherSearchResult.FontType.Monospace ? "JetBrains Mono" : "Space Grotesk"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.modelData.type + (row.modelData.comment ? " · " + row.modelData.comment : "")
                    font.pixelSize: 11
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
            // right side: the extra actions of the result (app actions, copy/delete
            // on the clipboard) and what Enter does
            Row {
                id: tail
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: row.chosen || rowArea.containsMouse ? row.modelData.actions.slice(0, 3) : []
                    delegate: RippleButton {
                        id: act
                        required property var modelData
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: 10
                        colBackground: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.92)
                        onClicked: {
                            act.modelData.execute();
                            menu.done();
                        }
                        StyledToolTip { text: act.modelData.name }
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                // app actions without an icon get a generic one
                                readonly property bool fallback: act.modelData.iconType !== LauncherSearchResult.IconType.Material && act.modelData.iconName === ""
                                visible: act.modelData.iconType === LauncherSearchResult.IconType.Material || fallback
                                text: fallback ? "open_in_new" : act.modelData.iconName
                                iconSize: 16
                                color: Appearance.colors.colOnLayer0
                            }
                            IconImage {
                                anchors.centerIn: parent
                                visible: act.modelData.iconType !== LauncherSearchResult.IconType.Material && act.modelData.iconName !== ""
                                implicitSize: 16
                                source: visible ? Quickshell.iconPath(act.modelData.iconName, "application-x-executable") : ""
                            }
                        }
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.chosen && row.modelData.verb !== ""
                    text: row.modelData.verb + "  ↵"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
            }
            MouseArea {
                id: rowArea
                anchors.fill: parent
                anchors.rightMargin: tail.width + 12
                hoverEnabled: true
                onEntered: list.currentIndex = row.index
                onClicked: menu.run(row.modelData)
            }
        }
    }
}
