pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: the little of impasto's MonitorService that the desk reads. Mosaic
// does not arrange monitors, so this only names them: a board is kept per
// monitor description (model + serial), and the primary screen is the largest
// one lying down (a screen turned on its side comes last).
Singleton {
    id: root

    readonly property var monitors: Quickshell.screens.map(screen => ({
        name: screen.name,
        description: `${screen.model ?? ""} ${screen.serialNumber ?? ""}`.trim() || screen.name
    }))

    readonly property var primaryScreen: {
        let best = null
        for (const screen of Quickshell.screens)
            if (!best || (screen.width >= screen.height) > (best.width >= best.height)
                    || ((screen.width >= screen.height) === (best.width >= best.height)
                        && screen.width * screen.height > best.width * best.height))
                best = screen
        return best
    }
    readonly property string effectivePrimaryName: root.primaryScreen?.name ?? ""

    function monitorFor(description: string): var {
        return root.monitors.find(monitor => monitor.description === description) ?? null
    }
    function descriptionFor(name: string): string {
        return root.monitors.find(monitor => monitor.name === name)?.description ?? ""
    }
}
