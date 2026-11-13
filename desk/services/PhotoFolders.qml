pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Mosaic OS: photo widgets that show a folder (the row's `folder`) instead of
// one picture, like the ii's two frames did: the 20 newest pictures in it, a
// new one at random every 70 s, the folder read again every 5 min. A folder on
// the phone (KDE Connect) that is not mounted just shows nothing until it is.
Singleton {
    id: root

    // folders some widget shows (DesktopService fills this)
    readonly property var folders: {
        const out = []
        for (const widget of DesktopService.widgets)
            if (widget.id === "photo" && typeof widget.folder === "string" && widget.folder !== "" && out.indexOf(widget.folder) < 0)
                out.push(widget.folder)
        return out
    }
    property var lists: ({})  // folder -> [paths]
    property var shown: ({})  // folder -> path

    function current(folder: string): string {
        return root.shown[folder] ?? ""
    }

    function shuffle(): void {
        const next = Object.assign({}, root.shown)
        for (const folder in root.lists) {
            const list = root.lists[folder]
            if (list.length === 0) {
                delete next[folder]
                continue
            }
            let pick = list[Math.floor(Math.random() * list.length)]
            if (list.length > 1)
                while (pick === root.shown[folder])
                    pick = list[Math.floor(Math.random() * list.length)]
            next[folder] = pick
        }
        root.shown = next
    }

    onFoldersChanged: reader.reread()

    Process {
        id: reader
        function reread(): void {
            if (root.folders.length === 0)
                return
            reader.running = false
            reader.running = true
        }
        // one line per picture: "folder<TAB>path"
        command: ["bash", "-c", `for d in "$@"; do find "$d" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -20 | cut -d' ' -f2- | sed "s|^|$d\\t|"; done`, "sh"].concat(root.folders)
        stdout: StdioCollector {
            onStreamFinished: {
                const lists = {}
                for (const folder of root.folders)
                    lists[folder] = []
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab > 0 && lists[line.slice(0, tab)])
                        lists[line.slice(0, tab)].push(line.slice(tab + 1))
                }
                root.lists = lists
                // keep what is up if it is still there
                const kept = {}
                for (const folder in lists)
                    if (lists[folder].indexOf(root.shown[folder]) >= 0)
                        kept[folder] = root.shown[folder]
                root.shown = kept
                for (const folder in lists)
                    if (!kept[folder] && lists[folder].length > 0) {
                        root.shuffle()
                        break
                    }
            }
        }
    }

    Timer {
        interval: 70000
        repeat: true
        running: root.folders.length > 0
        onTriggered: root.shuffle()
    }
    Timer {
        interval: 300000
        repeat: true
        running: root.folders.length > 0
        onTriggered: reader.reread()
    }
}
