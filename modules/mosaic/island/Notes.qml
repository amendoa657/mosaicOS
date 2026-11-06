pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Notes, inside the card that drops out of the island (tools button or
// Super+Alt+N). Each tab is a plain .md file in ~/Documentos/Notas, so they open
// anywhere (Neovim too).
// - Tabs: + makes a new one, double click renames (Enter saves, Esc gives up),
//   the × on the current tab deletes it (a second click confirms).
// - Writing: plain text. A line starting with "* " shows as a bullet "• ";
//   Enter on a bullet starts the next one, Enter on an empty bullet ends the list.
//   The file keeps "* " (normal Markdown); the bullet is only how it is shown.
// - It saves by itself 600 ms after you stop typing.
Item {
    id: notes
    signal done()

    readonly property string folder: Quickshell.env("HOME") + "/Documentos/Notas"
    property string current: "" // file name of the open tab
    implicitHeight: 380

    function focusEditor() { editor.forceActiveFocus(); }

    // "* " at the start of a line <-> "• " on screen
    function toScreen(t) { return t.replace(/^(\s*)\* /gm, "$1• "); }
    function toFile(t) { return t.replace(/^(\s*)• /gm, "$1* "); }

    // ---------- the folder ----------
    Process { // make sure it exists (and has one note) the first time
        running: true
        command: ["sh", "-c", `mkdir -p '${notes.folder}' && ls '${notes.folder}'/*.md >/dev/null 2>&1 || printf '* ' > '${notes.folder}/Notas.md'`]
        onExited: folderModel.folder = "file://" + notes.folder
    }
    FolderListModel {
        id: folderModel
        nameFilters: ["*.md"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: {
            // keep a valid tab open
            if (count > 0 && (notes.current === "" || indexOf("file://" + notes.folder + "/" + notes.current) < 0))
                notes.current = get(0, "fileName");
        }
    }
    function tabName(file) { return file.replace(/\.md$/, ""); }

    function newTab() {
        notes.flush();
        let n = 1;
        while (folderModel.indexOf("file://" + notes.folder + `/Nota ${n}.md`) >= 0)
            n++;
        const name = `Nota ${n}.md`;
        creator.command = ["sh", "-c", `printf '' > "$1"`, "sh", notes.folder + "/" + name];
        creator.running = true;
        notes.current = name;
    }
    function renameTab(from, to) {
        to = to.trim().replace(/[\/\\]/g, "-");
        if (to === "" || to + ".md" === from)
            return;
        mover.command = ["mv", "-n", notes.folder + "/" + from, notes.folder + "/" + to + ".md"];
        mover.running = true;
        notes.current = to + ".md";
    }
    function deleteTab(file) {
        remover.command = ["gio", "trash", notes.folder + "/" + file]; // to the trash, not gone forever
        remover.running = true;
        notes.current = "";
    }
    Process { id: creator }
    Process { id: mover }
    Process { id: remover }

    // ---------- the open note ----------
    FileView {
        id: file
        path: notes.current !== "" ? notes.folder + "/" + notes.current : ""
        printErrors: false
        watchChanges: true // edited outside (Neovim...): shows up here
        onFileChanged: reload()
        onLoaded: {
            const t = notes.toScreen(text());
            if (editor.text !== t) {
                editor.loading = true;
                editor.text = t;
                editor.loading = false;
            }
        }
    }
    Timer { // saves 600 ms after the last key
        id: saveLater
        interval: 600
        onTriggered: if (notes.current !== "") file.setText(notes.toFile(editor.text))
    }
    // write what is pending now (before switching tabs or closing)
    function flush() {
        if (saveLater.running) {
            saveLater.stop();
            file.setText(notes.toFile(editor.text));
        }
    }
    onCurrentChanged: {
        editor.loading = true;
        editor.text = "";
        editor.loading = false;
    }

    // ---------- tabs ----------
    Row {
        id: tabs
        width: parent.width
        height: 34
        spacing: 6
        ListView {
            id: tabList
            width: Math.min(contentWidth, tabs.width - addTab.width - 6)
            height: parent.height
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            model: folderModel
            delegate: Rectangle {
                id: tab
                required property string fileName
                required property int index
                readonly property bool on: fileName === notes.current
                property bool editing: false
                property bool confirmDelete: false
                width: (editing ? nameEdit.implicitWidth + 24 : label.implicitWidth + 24) + (on ? 22 : 0)
                height: 34
                radius: MosaicTheme.r(12)
                color: on ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78) : ColorUtils.transparentize(Appearance.colors.colOnLayer0, tabArea.containsMouse ? 0.88 : 0.94)
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                // tabs pop in one after the other
                property real born: 0
                Behavior on born { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                Timer { running: true; interval: 60 + tab.index * 30; onTriggered: tab.born = 1 }
                opacity: born
                scale: 0.85 + 0.15 * born

                StyledText {
                    id: label
                    visible: !tab.editing
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: notes.tabName(tab.fileName)
                    font.family: "Space Grotesk"
                    font.pixelSize: 13
                    font.weight: tab.on ? Font.DemiBold : Font.Normal
                    color: Appearance.colors.colOnLayer0
                }
                TextInput {
                    id: nameEdit
                    visible: tab.editing
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    font: label.font
                    color: Appearance.colors.colOnLayer0
                    selectionColor: Appearance.colors.colPrimary
                    Keys.onReturnPressed: {
                        notes.renameTab(tab.fileName, text);
                        tab.editing = false;
                        notes.focusEditor();
                    }
                    Keys.onEscapePressed: {
                        tab.editing = false;
                        notes.focusEditor();
                    }
                    onActiveFocusChanged: if (!activeFocus) tab.editing = false
                }
                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    anchors.rightMargin: tab.on ? 22 : 0
                    hoverEnabled: true
                    onClicked: {
                        notes.flush();
                        notes.current = tab.fileName;
                        notes.focusEditor();
                    }
                    onDoubleClicked: {
                        tab.editing = true;
                        nameEdit.text = notes.tabName(tab.fileName);
                        nameEdit.selectAll();
                        nameEdit.forceActiveFocus();
                    }
                }
                // × deletes the current tab: the first click arms it (turns red), the second confirms
                MaterialSymbol {
                    visible: tab.on && folderModel.count > 1
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "close"
                    iconSize: 15
                    color: tab.confirmDelete ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                    opacity: tab.confirmDelete ? 1 : 0.6
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: {
                            if (tab.confirmDelete)
                                notes.deleteTab(tab.fileName);
                            else {
                                tab.confirmDelete = true;
                                disarm.restart();
                            }
                        }
                    }
                    Timer { id: disarm; interval: 2500; onTriggered: tab.confirmDelete = false }
                }
            }
        }
        Rectangle { // + new tab
            id: addTab
            width: 34
            height: 34
            radius: MosaicTheme.r(12)
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, addArea.containsMouse ? 0.86 : 0.94)
            scale: addArea.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "add"
                iconSize: 18
                color: Appearance.colors.colOnLayer0
            }
            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notes.newTab()
            }
        }
    }

    // ---------- the page ----------
    Rectangle {
        anchors.top: tabs.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        radius: MosaicTheme.r(16)
        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.95)

        Flickable {
            id: page
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: editor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            TextArea.flickable: TextArea {
                id: editor
                property bool loading: false
                wrapMode: TextEdit.Wrap
                background: null
                padding: 0
                font.family: "Space Grotesk"
                font.pixelSize: 14
                color: Appearance.colors.colOnLayer0
                selectionColor: Appearance.colors.colPrimary
                placeholderText: "Escreva aqui…   (* no começo da linha vira •)"
                placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.55)
                onTextChanged: {
                    if (loading)
                        return;
                    // "* " typed at the start of a line becomes a bullet
                    const lineStart = text.lastIndexOf("\n", cursorPosition - 1) + 1;
                    if (text.substring(lineStart, cursorPosition).match(/^\s*\* $/)) {
                        const pos = cursorPosition;
                        const indent = text.substring(lineStart, pos - 2);
                        remove(lineStart, pos);
                        insert(lineStart, indent + "• ");
                    }
                    saveLater.restart();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        notes.flush();
                        notes.done();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        // keep the list going (or end it on an empty bullet)
                        const lineStart = text.lastIndexOf("\n", cursorPosition - 1) + 1;
                        const line = text.substring(lineStart, cursorPosition);
                        const m = line.match(/^(\s*)• (.*)$/);
                        if (!m)
                            return;
                        if (m[2].trim() === "")
                            remove(lineStart, cursorPosition);
                        else
                            insert(cursorPosition, "\n" + m[1] + "• ");
                        event.accepted = true;
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
