pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's PrivacyService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    readonly property bool active: false
    readonly property string who: ""
}
