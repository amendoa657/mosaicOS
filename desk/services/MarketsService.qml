pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's MarketsService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    readonly property string age: ""
    readonly property bool available: false
    readonly property int cardHeight: 0
    function change(item: var): string { return ""; }
    readonly property int chartHeight: 0
    function glyph(item: var): string { return ""; }
    readonly property var lead: null
    readonly property var others: []
    readonly property var pairs: []
    function price(item: var): string { return ""; }
    function release(): void {}
    function rising(item: var): bool { return false; }
    function shape(item: var): var { return null; }
    function short(item: var): string { return ""; }
    function subscribe(): void {}
    function tint(item: var): color { return "transparent"; }
}
