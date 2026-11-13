pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's ControlsService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    function door(id: string): var { return null; }
}
