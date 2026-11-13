import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common

// Mosaic OS: the "Desliga-tudo" panel, rough on purpose. One checkbox per piece
// of the shell (MosaicDebug); untick one and watch the GPU in `radeontop -c`.
// The GPU line here reads /sys/class/drm/card*/device/gpu_busy_percent once a
// second, only while the panel is open. Super+Alt+G or
// `qs -c mosaic ipc call mosaicDebug toggle`.
Scope {
    id: root
    property bool open: false

    IpcHandler {
        target: "mosaicDebug"
        function toggle(): void { root.open = !root.open; }
        // set("ilha", false): the same switches, from a script
        function set(name: string, on: bool): void { if (name in MosaicDebug) MosaicDebug[name] = on; }
    }
    GlobalShortcut {
        name: "mosaicDebugToggle"
        description: "Abre e fecha o painel que desliga partes do Mosaic"
        onPressed: root.open = !root.open
    }

    LazyLoader {
        active: root.open
        component: FloatingWindow {
            id: win
            title: "Mosaic: desliga-tudo"
            implicitWidth: 260
            implicitHeight: 520
            color: "#202020"
            onClosed: root.open = false // the window's own close button

            property int busy: -1
            Process {
                id: reader
                command: ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1"]
                stdout: StdioCollector { onStreamFinished: win.busy = parseInt(this.text) }
            }
            Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: reader.running = true }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2
                Text { text: "GPU agora: " + (win.busy < 0 || isNaN(win.busy) ? "?" : win.busy + "%"); color: "white"; font.pixelSize: 16; font.bold: true }
                Text { text: "desmarque e veja a GPU cair"; color: "#aaa"; font.pixelSize: 11 }
                Repeater {
                    model: [
                        ["papel", "Papel de parede"], ["pontos", "Pontos de fundo"], ["widgets", "Widgets (desk inteiro)"],
                        ["ilha", "Ilha"], ["dock", "Dock"], ["barra", "Barra de cima"],
                        ["ladoEsq", "Lateral esquerda"], ["ladoDir", "Lateral direita"],
                        ["cantos", "Cantinhos da tela"], ["stage", "Stage Manager"]
                    ]
                    CheckBox {
                        required property var modelData
                        text: modelData[1]
                        checked: MosaicDebug[modelData[0]]
                        onToggled: MosaicDebug[modelData[0]] = checked
                        palette.windowText: "white"
                        palette.text: "white"
                        palette.base: "#3a3a3a"
                    }
                }
                Button {
                    text: "Liga tudo de volta"
                    onClicked: {
                        for (const k of ["papel", "pontos", "widgets", "ilha", "dock", "barra", "ladoEsq", "ladoDir", "cantos", "stage"])
                            MosaicDebug[k] = true;
                    }
                }
            }
        }
    }
}
