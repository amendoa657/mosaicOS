import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The apps used last, newest first, for the start menu. An app counts as used
// when it is opened from the menu or when a window of it appears (opened from
// anywhere). Kept in ~/.cache/mosaic-os/recent-apps.json, at most `limit`.
Item {
    id: recents
    visible: false
    property int limit: 8
    property var ids: [] // desktop entry ids

    readonly property string path: Quickshell.env("HOME") + "/.cache/mosaic-os/recent-apps.json"

    function add(id) {
        if (!id)
            return;
        const list = [id].concat(recents.ids.filter(i => i !== id)).slice(0, recents.limit);
        if (JSON.stringify(list) === JSON.stringify(recents.ids))
            return;
        recents.ids = list;
        file.setText(JSON.stringify(list));
    }

    FileView {
        id: file
        path: recents.path
        printErrors: false // it only exists after the first app
        atomicWrites: true
        onLoaded: {
            try {
                const l = JSON.parse(text());
                if (Array.isArray(l))
                    recents.ids = l;
            } catch (e) {}
        }
    }
    Process { // make sure the folder exists before the first write
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/mosaic-os"]
    }

    // a new window = that app was used. Only the difference from the last list
    // is looked at, and only when the window list changes.
    property var seen: []
    property bool primed: false // the windows already open at start don't count
    readonly property var appIds: ToplevelManager.toplevels.values.map(t => t.appId)
    onAppIdsChanged: {
        if (recents.primed)
            for (const a of recents.appIds.filter(a => a && !recents.seen.includes(a)))
                recents.add(DesktopEntries.heuristicLookup(a)?.id ?? "");
        recents.seen = recents.appIds.slice();
        recents.primed = true;
    }
}
