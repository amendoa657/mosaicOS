// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   S C R E E N                                                  │
// │   session lock · one surface per screen                                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"
import "../services"
import qs.modules.common

// The compositor's lock, through ext-session-lock. The compositor hides
// everything else once locked and keeps it hidden if this process dies, so a
// crash leaves the session locked rather than open. The protocol requires a
// surface on every output before the session counts as locked.
WlSessionLock {
    id: root

    locked: LockService.locked

    // Published so anything waiting for the screen to be covered has a real
    // signal to wait on. A handler and not a `Binding` child: the lock's
    // default property is its surface, and a child declared beside it binds
    // nothing.
    onSecureStateChanged: LockService.secure = root.secure

    WlSessionLockSurface {
        id: surface
        CornerGuard {}

        // Mosaic OS: the macOS theme has a lock of its own (MacLockSurface.qml)
        Loader {
            anchors.fill: parent
            focus: true
            sourceComponent: MosaicTheme.mac ? macSurface : impastoSurface
            // The surface exists before it can hold the keyboard, so the field
            // claims it once the surface is up rather than on its own
            // completion.
            onLoaded: item.claim()
        }
        Component {
            id: impastoSurface
            LockSurface {
                output: surface.screen?.name ?? ""
                onSubmitted: password => LockService.submit(password)
            }
        }
        Component {
            id: macSurface
            MacLockSurface {
                output: surface.screen?.name ?? ""
                onSubmitted: password => LockService.submit(password)
            }
        }
    }
}
