pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's PetService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    readonly property int activeIndex: 0
    function bringOut(index: int): void {}
    readonly property bool canFeed: false
    readonly property bool canPlay: false
    readonly property bool complete: false
    readonly property var family: []
    function feed(): void {}
    readonly property bool hatched: false
    readonly property int level: 0
    readonly property int levelsToNextEgg: 0
    readonly property string mood: ""
    function moodAt(index: int): string { return ""; }
    readonly property string moodLine: ""
    readonly property string name: ""
    readonly property var pet: null
    function play(): void {}
    readonly property real progress: 0
    readonly property bool ready: false
    function recordAt(index: int): var { return null; }
    function release(): void {}
    readonly property var species: []
    function speciesOf(record: var): var { return null; }
    function subscribe(): void {}
    readonly property int threshold: 0
    function titleOf(record: var): string { return ""; }
    readonly property int xp: 0
}
