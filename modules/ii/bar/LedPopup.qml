import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Menu da fita LED (LotusLamp X) aberto pelo botão de sol da barra.
// Fala com ~/ledstrip/led, que manda os comandos pelo celular (app LED Bridge).
LazyLoader {
    id: root

    property Item anchorItem
    // Mosaic OS: opened from the island, the menu hangs from the top
    property bool atTop: !Config.options.bar.bottom
    property real edgeMargin: Appearance.sizes.barHeight
    property bool open: false
    readonly property string ledCommand: Quickshell.env("HOME") + "/ledstrip/led"

    // Estado vindo de `led --json status`
    property bool loading: true
    property string error: ""
    property bool stripOn: false
    property bool connected: false
    property string device: ""
    property string statusText: ""
    property color stripColor: "white"
    property real brightness: 1
    property real speed: 0.5
    property string anim: ""
    property bool followTheme: false
    property bool audioOn: false
    property var themePalette: []
    property var palettes: [] // [{name, label, colors}] das paletas do matugen
    property string paletteName: "wallpaper"
    property string hoveredAnim: ""
    // Abas do rodapé: lembram se estavam abertas entre uma abertura do menu e outra
    property bool animSectionOpen: false
    property bool optionsSectionOpen: false

    // Animações do celular, todas com a paleta do matugen
    readonly property var animations: [
        { name: "palette", icon: "gradient", label: "Paleta", about: "Passa suavemente de uma cor do tema para a outra" },
        { name: "breathe", icon: "air", label: "Respirar", about: "Acende e apaga devagar, trocando de cor a cada respiração" },
        { name: "jump", icon: "bolt", label: "Pulo", about: "Troca de cor do tema de uma vez, no ritmo da velocidade" },
        { name: "candle", icon: "local_fire_department", label: "Vela", about: "Tremula como chama, misturando as duas primeiras cores do tema" },
        { name: "aurora", icon: "waves", label: "Aurora", about: "As cores do tema se misturam e ondulam devagar, com o brilho variando" }
    ]
    readonly property var shownAnim: animations.find(a => a.name === (hoveredAnim || anim))

    active: open

    function refresh() {
        root.loading = true;
        run(["--json", "status"]);
    }

    function run(args) {
        const p = ledProcess.createObject(root, { command: [root.ledCommand].concat(args) });
        p.running = true;
    }

    function applyStatus(text) {
        root.loading = false;
        let st;
        try {
            st = JSON.parse(text);
        } catch (e) {
            root.error = "O comando led não respondeu";
            return;
        }
        if (st.error) {
            root.error = st.error;
            return;
        }
        root.error = "";
        root.stripOn = st.on;
        root.connected = st.connected;
        root.device = st.device ?? "";
        root.statusText = st.status;
        root.stripColor = "#" + st.color;
        root.brightness = st.brightness / 100;
        root.speed = st.speed / 100;
        root.anim = st.anim ?? "";
        root.followTheme = st.follow ?? false;
        root.audioOn = st.audio ?? false;
        root.themePalette = (st.palette ?? []).map(c => "#" + c);
        root.palettes = st.palettes ?? [];
        root.paletteName = st.paletteName ?? "wallpaper";
    }

    function pickColor(c) {
        root.stripColor = c;
        root.stripOn = true;
        root.anim = "";
        run(["--json", "color", c.toString().slice(1, 7)]);
    }

    Component {
        id: ledProcess
        Process {
            id: proc
            stdout: StdioCollector {
                onStreamFinished: if (text.length > 0) root.applyStatus(text)
            }
            onExited: proc.destroy()
        }
    }

    // Papel de parede novo -> matugen reescreve color.txt -> a fita acompanha (se "seguir o tema" estiver ligado).
    // Só a barra da primeira tela avisa, para não mandar o comando uma vez por monitor.
    property FileView themeWatcher: FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/color.txt"
        watchChanges: true
        onFileChanged: themeDebounce.restart()
    }
    property Timer themeDebounce: Timer {
        interval: 1500 // o matugen grava vários arquivos em sequência
        onTriggered: {
            const myScreen = root.anchorItem?.QsWindow?.window?.screen?.name ?? root.QsWindow?.window?.screen?.name;
            if (myScreen && myScreen !== Quickshell.screens[0]?.name) return;
            root.run(["--json", "theme-changed"]);
        }
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"
        anchors.right: true
        anchors.top: true
        anchors.bottom: !false
        implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
          left: 0
          right: 0
          top: 0
          bottom: 292
        }
        mask: Region { item: background }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        Component.onCompleted: root.refresh()

        HyprlandFocusGrab {
            active: true
            windows: [popupWindow, root.anchorItem?.QsWindow?.window]
            onCleared: root.open = false
        }

        StyledRectangularShadow {
            target: background
        }

        Rectangle {
            id: background
            anchors.fill: parent
            anchors.margins: Appearance.sizes.elevationMargin
            implicitWidth: 320
            implicitHeight: content.implicitHeight + 32
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 12

                // Cabeçalho: nome da fita e liga/desliga
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: root.stripOn && !root.error ? root.stripColor : Appearance.colors.colLayer2
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "light"
                            iconSize: 20
                            color: root.stripOn && !root.error && root.stripColor.hslLightness > 0.6 ? "black"
                                : root.stripOn && !root.error ? "white" : Appearance.colors.colOnLayer2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: "Fita LED"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: root.loading ? "Falando com o celular…"
                                : root.error ? root.error
                                : `${root.device || "sem fita"} · ${root.statusText}`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.error ? Appearance.colors.colError : Appearance.colors.colSubtext
                        }
                    }

                    StyledSwitch {
                        enabled: root.connected && !root.error
                        checked: root.stripOn
                        onClicked: {
                            root.stripOn = checked;
                            root.run(["--json", checked ? "on" : "off"]);
                        }
                    }
                }

                // Tudo abaixo só faz sentido com a fita conectada
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    enabled: root.connected && !root.error
                    opacity: enabled ? 1 : 0.4

                    // Roda de cores grande no centro: matiz em volta, saturação para o centro (brilho fica no slider)
                    Item {
                        id: wheel
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        implicitWidth: 230
                        implicitHeight: 230
                        readonly property real radius: width / 2
                        property color pending

                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d");
                                const r = wheel.radius;
                                ctx.reset();
                                ctx.beginPath();
                                ctx.arc(r, r, r, 0, Math.PI * 2);
                                ctx.closePath();
                                ctx.clip();
                                const hue = ctx.createConicalGradient(r, r, 0);
                                for (let i = 0; i <= 6; i++) hue.addColorStop(i / 6, Qt.hsva((i % 6) / 6, 1, 1, 1));
                                ctx.fillStyle = hue;
                                ctx.fillRect(0, 0, width, height);
                                const white = ctx.createRadialGradient(r, r, 0, r, r, r);
                                white.addColorStop(0, "white");
                                white.addColorStop(1, Qt.rgba(1, 1, 1, 0));
                                ctx.fillStyle = white;
                                ctx.fillRect(0, 0, width, height);
                            }
                        }

                        // Marcador da cor atual
                        Rectangle {
                            readonly property real angle: root.stripColor.hsvHue * Math.PI * 2
                            readonly property real dist: Math.max(0, root.stripColor.hsvSaturation) * wheel.radius
                            x: wheel.radius + Math.cos(angle) * dist - width / 2
                            y: wheel.radius - Math.sin(angle) * dist - height / 2
                            width: 22
                            height: 22
                            radius: 11
                            color: root.stripColor
                            border.width: 3
                            border.color: "white"
                            visible: !root.anim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.CrossCursor
                            function pick(mx, my) {
                                const dx = mx - wheel.radius, dy = wheel.radius - my;
                                const sat = Math.min(1, Math.sqrt(dx * dx + dy * dy) / wheel.radius);
                                const hue = ((Math.atan2(dy, dx) / (Math.PI * 2)) + 1) % 1;
                                const c = Qt.hsva(hue, sat, 1, 1);
                                root.stripColor = c;
                                root.anim = "";
                                wheel.pending = c;
                                if (!wheelTimer.running) wheelTimer.start();
                            }
                            onPressed: mouse => pick(mouse.x, mouse.y)
                            onPositionChanged: mouse => { if (pressed) pick(mouse.x, mouse.y); }
                            onReleased: { wheelTimer.stop(); root.pickColor(wheel.pending); }
                        }

                        // Enquanto arrasta, manda no máximo ~8 cores por segundo
                        Timer {
                            id: wheelTimer
                            interval: 120
                            onTriggered: root.pickColor(wheel.pending)
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.anim ? "Animação: " + (root.animations.find(a => a.name === root.anim)?.label ?? root.anim)
                            : root.stripColor.toString().toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                    }

                    // Paleta do matugen: a escolhida vale para seguir o tema, animações e música
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledComboBox {
                            Layout.fillWidth: true
                            buttonIcon: "palette"
                            textRole: "label"
                            model: root.palettes
                            currentIndex: Math.max(0, root.palettes.findIndex(p => p.name === root.paletteName))
                            onActivated: index => {
                                const p = root.palettes[index];
                                root.paletteName = p.name;
                                root.themePalette = p.colors.map(c => "#" + c);
                                root.run(["--json", "palette", p.name]);
                            }
                        }
                        Repeater {
                            model: root.themePalette
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool selected: !root.anim && Qt.colorEqual(root.stripColor, modelData)
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                color: modelData
                                border.width: selected ? 3 : 1
                                border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pickColor(parent.modelData)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "brightness_6"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledSlider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            value: root.brightness
                            onMoved: brightnessTimer.restart()
                        }
                    }

                    LedSection {
                        icon: "animation"
                        title: "Animações"
                        summary: root.anim ? (root.animations.find(a => a.name === root.anim)?.label ?? "") : "nenhuma"
                        expanded: root.animSectionOpen
                        onExpandedChanged: root.animSectionOpen = expanded

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: root.animations
                                delegate: RippleButton {
                                    id: animButton
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: Appearance.colors.colLayer2
                                    toggled: root.anim === modelData.name
                                    onHoveredChanged: root.hoveredAnim = hovered ? modelData.name : ""
                                    onClicked: {
                                        root.anim = modelData.name;
                                        root.stripOn = true;
                                        root.run(["--json", "anim", modelData.name]);
                                    }
                                    contentItem: ColumnLayout {
                                        spacing: 0
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: animButton.modelData.icon
                                            iconSize: Appearance.font.pixelSize.large
                                            color: animButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: animButton.modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: animButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                                        }
                                    }
                                }
                            }
                        }
                        // Como a animação funciona (a que está sob o mouse, ou a que está rodando)
                        StyledText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: root.shownAnim ? root.shownAnim.about : "Usam a paleta escolhida e rodam no celular, mesmo com o PC desligado."
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: "speed"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnLayer2
                            }
                            StyledSlider {
                                id: speedSlider
                                Layout.fillWidth: true
                                value: root.speed
                                onMoved: speedTimer.restart()
                            }
                        }
                    }

                    LedSection {
                        icon: "tune"
                        title: "Opções"
                        summary: [root.followTheme ? "seguindo o matugen" : "", root.audioOn ? "música" : ""].filter(x => x).join(" · ")
                        expanded: root.optionsSectionOpen
                        onExpandedChanged: root.optionsSectionOpen = expanded

                        LedSettingRow {
                            icon: "wallpaper"
                            label: "Seguir o matugen"
                            checked: root.followTheme
                            onToggled: value => {
                                root.followTheme = value;
                                root.run(["--json", "follow", value ? "on" : "off"]);
                            }
                        }
                        LedSettingRow {
                            icon: "graphic_eq"
                            label: "Modo música"
                            checked: root.audioOn
                            onToggled: value => {
                                root.audioOn = value;
                                root.run(["--json", "audio", value ? "start" : "stop"]);
                            }
                        }
                    }
                }
            }

            // Sliders mandam só depois de parar de arrastar um instante, para não lotar a fila BLE
            Timer {
                id: brightnessTimer
                interval: 150
                onTriggered: root.run(["--json", "brightness", Math.round(brightnessSlider.value * 100).toString()])
            }
            Timer {
                id: speedTimer
                interval: 150
                onTriggered: root.run(["--json", "speed", Math.round(speedSlider.value * 100).toString()])
            }
        }
    }
}
