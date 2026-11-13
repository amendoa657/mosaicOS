pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's CodexService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    readonly property string age: ""
    readonly property bool available: false
    function current(limit: var): bool { return false; }
    readonly property string figure: ""
    readonly property var fullest: null
    readonly property string fullestName: ""
    readonly property real gauge: 0
    readonly property var limits: []
    readonly property bool measured: false
    readonly property string plan: ""
    function release(): void {}
    function subscribe(): void {}
    readonly property color tint: "transparent"
    function windowLine(limit: var): string { return ""; }
}
