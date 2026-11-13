pragma Singleton

import QtQuick
import Quickshell

// Mosaic OS: a stand-in for impasto's NotificationService. Mosaic has its own (or does
// without), so only what the desk and the lock read is here, inert.
Singleton {
    id: root
    function clearHistory(): void {}
    function defaultAction(notification: var): var { return null; }
    readonly property bool doNotDisturb: false
    readonly property var history: []
    function iconOf(named: string, appName: string): string { return ""; }
    function open(entry: var): bool { return false; }
    function openOf(entry: var): var { return null; }
    function remove(entry: var): void {}
    function standIn(critical: bool): string { return ""; }
    function toggleDoNotDisturb(): void {}
}
