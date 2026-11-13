import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import "./lock"
import "./services" as Desk

// Mosaic OS: the lock screen from impasto (github.com/andreumassanet/impasto,
// GPL-3.0): the desktop blurred behind, the clock, what is playing with its
// lyrics, the field and the power buttons. It replaces the ii's lock surface
// but answers to the same calls, so hypridle and the keys keep working:
//   qs -c mosaic ipc call lock activate|focus, and the global shortcuts
//   quickshell:lock / quickshell:lockFocus.
// GlobalStates.screenLocked follows the lock, for the ii parts that hide.
Scope {
    id: root

    function lock(): void {
        if (Config.options.lock.useHyprlock) {
            Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"]);
            return;
        }
        Desk.LockService.lock();
    }

    LockScreen {}

    // the ii parts read GlobalStates; something setting it directly locks too
    Connections {
        target: Desk.LockService
        function onLockedChanged(): void {
            GlobalStates.screenLocked = Desk.LockService.locked;
        }
        function onUnlocked(): void {
            if (Config.options.lock.security.unlockKeyring && Desk.LockService.lastSecret !== "") {
                keyring.exec({
                    environment: ({ "UNLOCK_PASSWORD": Desk.LockService.lastSecret }),
                    command: ["bash", "-c", Quickshell.shellPath("scripts/keyring/unlock.sh")]
                });
            }
            Desk.LockService.lastSecret = "";
        }
    }
    Connections {
        target: GlobalStates
        function onScreenLockedChanged(): void {
            if (GlobalStates.screenLocked && !Desk.LockService.locked)
                root.lock();
        }
    }
    Process {
        id: keyring
        onExited: KeyringStorage.fetchKeyringData()
    }

    IpcHandler {
        target: "lock"
        function activate(): void { root.lock(); }
        function focus(): void { Desk.LockService.rouse(); }
    }
    GlobalShortcut {
        name: "lock"
        description: "Locks the screen"
        onPressed: root.lock()
    }
    GlobalShortcut {
        name: "lockFocus"
        description: "Wakes the lock screen after the system sleeps"
        onPressed: Desk.LockService.rouse()
    }

    // lock on login, when the ii setting asks for it
    function initIfReady(): void {
        if (!Config.ready || !Persistent.ready)
            return;
        if (Config.options.lock.launchOnStartup && Persistent.isNewHyprlandInstance)
            root.lock();
        else
            KeyringStorage.fetchKeyringData();
    }
    Connections {
        target: Config
        function onReadyChanged(): void { root.initIfReady(); }
    }
    Connections {
        target: Persistent
        function onReadyChanged(): void { root.initIfReady(); }
    }
}
