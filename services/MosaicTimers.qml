pragma Singleton
import QtQuick
import Quickshell

// Timers typed in the start menu: "5m chá", "timer 90s", "1h20m pizza".
// parse(text) says whether the text is a timer (and how long, and its label);
// start() keeps it running, and when it ends a notification goes out, which
// the island shows like any other.
// Idea from pocket-dots' launcher timers (diegoMalagrida/pocket-dots, GPL-3.0).
Singleton {
    id: root

    property var running: [] // { label, ends (ms since epoch) }

    // "5m chá" -> { ms: 300000, label: "chá", text: "5 min" }, or null
    function parse(text) {
        const m = text.trim().match(/^(?:timer\s+)?((?:\d+\s*h)?\s*(?:\d+\s*m(?:in)?)?\s*(?:\d+\s*s)?)(?:\s+(.*))?$/i);
        if (!m || m[1].trim() === "")
            return null;
        const part = (unit) => {
            const r = m[1].match(new RegExp(`(\\d+)\\s*${unit}`, "i"));
            return r ? parseInt(r[1]) : 0;
        };
        const h = part("h"), min = part("m"), s = part("s");
        const ms = ((h * 60 + min) * 60 + s) * 1000;
        if (ms <= 0)
            return null;
        const bits = [];
        if (h) bits.push(`${h} h`);
        if (min) bits.push(`${min} min`);
        if (s) bits.push(`${s} s`);
        return { ms: ms, label: (m[2] ?? "").trim(), text: bits.join(" ") };
    }

    function start(t) {
        if (!t)
            return;
        const label = t.label || "Timer";
        root.running = root.running.concat([{ label: label, ends: Date.now() + t.ms }]);
        timerComp.createObject(root, { interval: t.ms, label: label, text: t.text });
        Quickshell.execDetached(["notify-send", "-a", "Timer", "-i", "alarm", `Timer de ${t.text}`, `${label} — começou`]);
    }

    Component {
        id: timerComp
        Timer {
            property string label: ""
            property string text: ""
            running: true
            onTriggered: {
                Quickshell.execDetached(["notify-send", "-a", "Timer", "-i", "alarm", "-u", "critical", `${label}`, `Acabou o timer de ${text}`]);
                root.running = root.running.filter(r => r.label !== label || r.ends > Date.now() + 500);
                destroy();
            }
        }
    }
}
