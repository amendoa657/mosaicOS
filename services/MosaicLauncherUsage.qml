pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// How often each app was opened from the start menu, so the search can put the
// ones you use first. Kept in ~/.local/state/mosaic-os/launcher-usage.json as
// { "<desktop id>": count }.
// Idea from pocket-dots' LauncherUsage (diegoMalagrida/pocket-dots, GPL-3.0).
Singleton {
    id: root

    property var counts: ({})

    function countOf(id) { return root.counts[id] ?? 0; }
    function add(id) {
        if (!id)
            return;
        const next = Object.assign({}, root.counts);
        next[id] = (next[id] ?? 0) + 1;
        root.counts = next;
        file.setText(JSON.stringify(next));
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/mosaic-os/launcher-usage.json"
        printErrors: false // only exists after the first app is opened
        onLoaded: {
            try {
                root.counts = JSON.parse(file.text()) ?? {};
            } catch (e) {
                root.counts = {};
            }
        }
    }
}
