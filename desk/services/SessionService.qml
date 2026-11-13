pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: the little of impasto's SessionService the lock uses, its power
// buttons. Locking and sleeping stay with the ii (hypridle, the Session service).
Singleton {
    id: root

    function run(actionId: string): void {
        switch (actionId) {
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"])
            break
        case "shutdown":
            Quickshell.execDetached(["systemctl", "poweroff"])
            break
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"])
            break
        default:
            console.warn("Unknown session action:", actionId)
        }
    }
}
