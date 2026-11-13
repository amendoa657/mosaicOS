pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's BrightnessService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    readonly property bool available: false
    readonly property var dimmable: null
    readonly property string icon: ""
    readonly property int percent: 0
    function refresh(): void {}
    readonly property bool several: false
}
