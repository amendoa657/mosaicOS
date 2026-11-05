import QtQuick
import Quickshell
import Quickshell.Io

// The phone, through KDE Connect, for the island: battery (and when it starts
// charging), calls (ringing, answered, missed) and when it connects or leaves.
// Instead of asking the phone every few seconds, it listens to the signals KDE
// Connect already sends on D-Bus (dbus-monitor), so it costs nothing while idle:
//   org.kde.kdeconnect.device.battery    refreshed(bool isCharging, int charge)
//   org.kde.kdeconnect.device.telephony  callReceived(string event, string number, string contactName)
//   org.kde.kdeconnect.device            reachableChanged(bool reachable)
// event is "ringing", "talking" or "missedCall".
Item {
    id: link
    visible: false

    property string deviceId: "fe08adfa88664ff488cafe2d338d96fd"
    readonly property string devicePath: "/modules/kdeconnect/devices/" + deviceId

    property string name: "Celular"
    property bool reachable: false
    property bool charging: false
    property int charge: -1 // percent, -1 = unknown

    signal chargingStarted()
    signal chargingStopped()
    signal call(string event, string number, string contactName)
    signal connected()
    signal disconnected()

    // silence the ringing phone (the only call action KDE Connect offers)
    function mute() {
        Quickshell.execDetached(["qdbus", "org.kde.kdeconnect", link.devicePath + "/telephony", "org.kde.kdeconnect.device.telephony.sendMutePacket"]);
    }

    // ---------- the starting state, asked once ----------
    Process {
        running: true
        command: ["sh", "-c", `qdbus org.kde.kdeconnect ${link.devicePath} org.kde.kdeconnect.device.name; `
            + `qdbus org.kde.kdeconnect ${link.devicePath} org.kde.kdeconnect.device.isReachable; `
            + `qdbus org.kde.kdeconnect ${link.devicePath}/battery org.kde.kdeconnect.device.battery.isCharging; `
            + `qdbus org.kde.kdeconnect ${link.devicePath}/battery org.kde.kdeconnect.device.battery.charge`]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n");
                if (l[0]) link.name = l[0].trim();
                link.reachable = (l[1] ?? "").trim() === "true";
                link.charging = (l[2] ?? "").trim() === "true";
                const c = parseInt(l[3]);
                link.charge = isNaN(c) ? -1 : c;
            }
        }
    }

    // ---------- then only listen ----------
    // dbus-monitor prints a header line per signal, then one line per argument
    Process {
        id: monitor
        running: true
        // setpriv --pdeathsig: it dies together with the shell (otherwise every restart left one behind)
        command: ["setpriv", "--pdeathsig", "TERM", "dbus-monitor", "--session",
            "type='signal',interface='org.kde.kdeconnect.device.battery',member='refreshed'",
            "type='signal',interface='org.kde.kdeconnect.device.telephony',member='callReceived'",
            "type='signal',interface='org.kde.kdeconnect.device',member='reachableChanged'"]
        property string member: ""
        property var args: []
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("signal ")) {
                    // only our phone
                    monitor.member = line.indexOf(link.deviceId) >= 0 ? (line.match(/member=(\w+)/)?.[1] ?? "") : "";
                    monitor.args = [];
                    return;
                }
                if (monitor.member === "")
                    return;
                const m = line.trim().match(/^(string|boolean|int32)\s+"?(.*?)"?$/);
                if (!m)
                    return;
                monitor.args.push(m[1] === "boolean" ? m[2] === "true" : m[1] === "int32" ? parseInt(m[2]) : m[2]);
                const want = { refreshed: 2, callReceived: 3, reachableChanged: 1 }[monitor.member] ?? 99;
                if (monitor.args.length === want) {
                    link.handle(monitor.member, monitor.args);
                    monitor.member = "";
                }
            }
        }
        // if it ever dies (session bus restart), start it again a bit later
        onExited: restartMonitor.start()
    }
    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }

    function handle(member, a) {
        if (member === "refreshed") {
            const wasCharging = link.charging;
            link.charging = a[0];
            link.charge = a[1];
            link.reachable = true;
            if (a[0] && !wasCharging)
                link.chargingStarted();
            else if (!a[0] && wasCharging)
                link.chargingStopped();
        } else if (member === "callReceived") {
            link.call(a[0], a[1], a[2]);
        } else if (member === "reachableChanged") {
            if (a[0] && !link.reachable)
                link.connected();
            else if (!a[0] && link.reachable)
                link.disconnected();
            link.reachable = a[0];
        }
    }
}
