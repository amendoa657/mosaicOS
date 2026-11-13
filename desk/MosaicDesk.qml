import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.common
import "./desktop"
import "./services"
import "./theme"

// Mosaic OS: the desk of widgets from impasto (github.com/andreumassanet/impasto,
// GPL-3.0), one board per screen, under the windows. The faces follow the Mosaic
// theme (DesktopService.mosaicStyle); right-click the wallpaper to arrange them.
//   qs -c mosaic ipc call mosaicDesk edit|done|list|add <module>|addOn <module> <screen>|remove <key>
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        Desktop {
            required property var modelData
            screen: modelData
        }
    }

    // ── FROM THE II'S WIDGETS (once) ────────────────────────────────────────
    // The first time the desk runs, the ii widgets that were on become desk
    // widgets near where they were (on the primary screen), the clock's quote
    // becomes a note, the two frames keep their phone folders, and the old
    // ones are switched off. A marker file says it is done.
    FileView {
        id: migrated
        path: SettingsService.stateDirectory + "/migrated-from-ii"
        printErrors: false
        onLoadFailed: migrateLater.start()
    }
    FileView {
        id: backup
        path: SettingsService.stateDirectory + "/backup/mosaic-config-antes-do-desk.json"
        printErrors: false
        blockLoading: true
    }
    Timer {
        id: migrateLater
        interval: 1500 // the settings and the boards have to be read first
        onTriggered: {
            if (!SettingsService.arrived || !DesktopService.boards[MonitorService.effectivePrimaryName]) {
                migrateLater.start()
                return
            }
            try {
                root.migrate(Config.options.background.widgets)
            } catch (error) {
                console.warn("[MosaicDesk] migration failed:", error, error.stack)
            }
        }
    }

    function migrate(old: var): void {
        const name = MonitorService.effectivePrimaryName
        const stride = Theme.desktopStride
        const top = DesktopService.insets.top
        const cell = (x, y) => ({ col: Math.max(0, Math.round(x / stride)), row: Math.max(0, Math.round((y - top) / stride)) })
        const place = (id, at, family, fields) => {
            const spot = DesktopService.nearestFree(name, at.col, at.row, family, "")
            if (!spot) {
                console.warn("[MosaicDesk] no room for", id, family, "near", at.col, at.row)
                return ""
            }
            const key = DesktopService.newKey(id)
            const row = Object.assign({ key: key, id: id, col: spot.col, row: spot.row, family: family }, fields ?? {})
            const screen = DesktopService.screenField(name)
            if (screen !== null)
                row.screen = screen
            DesktopService.write(DesktopService.widgets.concat([row]))
            console.log("[MosaicDesk] placed", id, family, "at", spot.col, spot.row)
            return key
        }
        const phone = "/run/user/1000/fe08adfa88664ff488cafe2d338d96fd/storage/emulated/0/Pictures/Gallery/owner/"
        if (old.clock.enable) {
            const at = cell(old.clock.x, old.clock.y)
            place("clock", at, "4x2")
            if (old.clock.quote?.enable && (old.clock.quote.text ?? "") !== "") {
                const note = NotesService.add("", old.clock.quote.text, "pink")
                DesktopService.noteToGrid(note, name, at.col + 2, at.row + 2)
            }
        }
        if (old.calendar.enable)
            place("calendar", cell(old.calendar.x, old.calendar.y), "4x4")
        if (old.weather.enable)
            place("weather", cell(old.weather.x, old.weather.y), "4x2")
        if (old.media.enable)
            place("media", cell(old.media.x, old.media.y), "4x2")
        if (old.photos.enable)
            place("photo", cell(old.photos.x, old.photos.y), "4x2", { folder: phone + "fotosLegais" })
        if (old.photos2.enable)
            place("photo", cell(old.photos2.x, old.photos2.y), "4x4", { folder: phone + "fotosLegaisEmPe" })
        if (old.anniversary.enable)
            place("anniversary", cell(old.anniversary.x, old.anniversary.y), "2x2",
                  { since: old.anniversary.startDate, label: old.anniversary.label })
        for (const key of ["clock", "calendar", "weather", "media", "photos", "photos2", "anniversary"])
            if (Config.options.background.widgets[key])
                Config.options.background.widgets[key].enable = false
        migrated.setText(new Date().toISOString() + "\n")
    }

    IpcHandler {
        target: "mosaicDesk"
        function edit(): void { DesktopService.edit(true, MonitorService.effectivePrimaryName); }
        function done(): void { DesktopService.edit(false); }
        // a widget by its module id (clock, weather, claude...), on the primary screen
        function add(id: string): string { return DesktopService.add(id, MonitorService.effectivePrimaryName); }
        function addOn(id: string, screen: string): string { return DesktopService.add(id, screen); }
        function remove(key: string): void { DesktopService.remove(key); }
        function keys(screen: string): string { return JSON.stringify({ keys: DesktopService.keysOn(screen), all: DesktopService.keys, wl: DesktopService.widgets.length, live: DesktopService.widgets.filter(w => !DesktopService.isEdge(w)).length, edge0: DesktopService.isEdge(DesktopService.widgets[0]), shown: DesktopService.shown.length, squares: DesktopService.squares.length, boards: DesktopService.boards, primary: MonitorService.effectivePrimaryName, monitors: MonitorService.monitors, insets: DesktopService.insets }); }
        // again, from the copy of the ii config taken before the first run
        function migrateAgain(): string {
            const saved = JSON.parse(backup.text()).background.widgets
            for (const widget of DesktopService.widgets)
                if (widget.id === "notes" && widget.note)
                    NotesService.remove(widget.note)
            DesktopService.write([])
            root.migrate(saved)
            return JSON.stringify(DesktopService.widgets)
        }
        function removeNote(key: string): void { NotesService.remove(key); }
        function list(): string { return JSON.stringify(DesktopService.widgets); }
    }
}
