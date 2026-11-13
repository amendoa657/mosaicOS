pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's GamesService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    function bestOf(id: string): int { return 0; }
    readonly property var catalogue: []
    function entry(id: string): var { return null; }
    readonly property string lastPlayed: ""
    readonly property var ranked: []
    readonly property bool ready: false
    function tintOf(id: string): color { return "transparent"; }
    readonly property int totalPlays: 0
}
