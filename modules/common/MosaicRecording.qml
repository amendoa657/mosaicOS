pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mosaic OS: is the screen being recorded (gpu-screen-recorder or wf-recorder,
// however it was started), and since when. One check every 3 s for the whole
// shell; the island and the top band used to run a pgrep each, every 1.5-2 s.
// ps gives how long the recorder has run (etimes), so the island's clock is
// right even for a recording started before we looked.
Singleton {
    id: root
    property bool recording: false
    property real startedAt: 0 // ms since epoch

    // check again shortly (after starting or stopping a recording)
    function recheckSoon(): void { soon.restart(); }

    Process {
        id: check
        command: ["sh", "-c", "pid=$(pidof -s gpu-screen-recorder wf-recorder) && ps -o etimes= -p \"$pid\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const secs = parseInt(this.text);
                const now = !isNaN(secs);
                if (now && !root.recording)
                    root.startedAt = Date.now() - secs * 1000;
                root.recording = now;
            }
        }
    }
    Timer { running: true; repeat: true; interval: 3000; triggeredOnStart: true; onTriggered: check.running = true }
    Timer { id: soon; interval: 700; onTriggered: check.running = true }
}
