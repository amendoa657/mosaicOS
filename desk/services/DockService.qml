pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's DockService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    function coveredOn(name: string): bool { return false; }
    readonly property string edge: "bottom" // the Mosaic dock
    function entryOf(id: string): var { return null; }
    function idFor(windowClass: string): string { return ""; }
    readonly property int zone: 76 // room kept for it
}
