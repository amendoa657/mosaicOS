pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common

// The wallpapers, shared by the carousel (MosaicCarousel) and the transition
// (MosaicWallFx): the folder's images, their average colour, the history, and
// "apply this one". It used to live inside the old wallpaper window.
// - The folder is the one the current wallpaper is in.
// - Thumbnails (480x300), previews (1100 px) and colours come from scripts/wallpaper-index.sh,
//   which only processes new images.
// - apply(path) does not change the wallpaper by itself: it hands the path to
//   MosaicWallFx (pending), which plays the transition and then commits.
Singleton {
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
    property string pending: "" // the wallpaper MosaicWallFx is bringing in
    // outline maps already made (scripts/wallfx): file name -> true
    readonly property string mapDir: Quickshell.env("HOME") + "/.cache/mosaic-os/wallfx"
    property var maps: ({})
    function mapFor(p) { return root.maps[root.baseName(p)] ? "file://" + root.mapDir + "/" + root.baseName(p) + ".png" : ""; }

    function baseName(p) { return p.substring(p.lastIndexOf("/") + 1); }
    function niceName(p) {
        const n = root.baseName(p);
        return n.substring(0, n.lastIndexOf(".") > 0 ? n.lastIndexOf(".") : n.length).replace(/[_-]+/g, " ");
    }
    function thumbFor(p) { return "file://" + root.cacheDir + "/thumbs/" + root.baseName(p) + ".jpg"; }
    function previewFor(p) { return "file://" + root.cacheDir + "/previews/" + root.baseName(p) + ".jpg"; }
    function toneOf(p) { return root.tones[root.baseName(p)] ?? ""; }

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

    // read the folder again (the carousel calls it when it opens)
    function refresh() {
        lister.running = true;
        historyFile.reload();
    }
    function apply(path) {
        if (path)
            root.pending = path;
    }
    function random() {
        const pool = root.files.filter(f => f !== root.currentPath);
        if (pool.length === 0) {
            wantRandom = true;
            root.refresh();
            return;
        }
        root.apply(pool[Math.floor(Math.random() * pool.length)]);
    }
    property bool wantRandom: false

    // the real change: the ii script (wallpaper + Matugen colours), and a line in the history
    function commit(path) {
        Wallpapers.select(path);
        historyWriter.command = ["sh", "-c", `mkdir -p '${root.cacheDir}' && printf '%s\\n' "$1" >> '${root.cacheDir}/history'`, "sh", path];
        historyWriter.running = true;
    }
    Process { id: historyWriter }

    Process {
        id: lister
        command: ["sh", "-c", `find '${root.folder}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = this.text.split("\n").filter(l => l.trim() !== "");
                indexer.running = true;
                if (root.wantRandom) {
                    root.wantRandom = false;
                    root.random();
                }
            }
        }
    }
    Process {
        id: indexer
        command: [Quickshell.shellPath("scripts/wallpaper-index.sh"), root.folder]
        onExited: {
            toneFile.reload();
            mapLister.running = true;
            warmer.running = true;
        }
    }
    // the outline maps: list the ones there are, and make the missing ones in the
    // background (lowest priority; only once the cut-out is installed)
    Process {
        id: mapLister
        command: ["sh", "-c", `ls '${root.mapDir}' 2>/dev/null | grep '\\.png$'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of this.text.split("\n"))
                    if (l.endsWith(".png"))
                        m[l.slice(0, -4)] = true;
                root.maps = m;
            }
        }
    }
    Process {
        id: warmer
        command: [Quickshell.shellPath("scripts/wallfx/wallfx-warm.sh"), root.folder]
        onExited: mapLister.running = true
    }
    Component.onCompleted: mapLister.running = true
    FileView {
        id: toneFile
        path: root.cacheDir + "/colors.tsv"
        printErrors: false
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
}
