pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mosaic.island

// The Mosaic OS settings window: the themes on the left, and a tab per part
// (Widgets, Gravação, Ilha, Aparência, Dock, Apps, Áreas). The wallpapers left it
// for their own carousel (MosaicCarousel), opened from the right sidebar.
// Opens with the palette button on the right sidebar, Super+Alt+T or the IPC:
//   qs -c mosaic ipc call mosaicSettings toggle|widgets|recording|island|look|dock|apps|areas
// Layout idea from hyprdots (fedyaqq34356/hyprdots, GPL-3.0), in the Mosaic style.
Scope {
    id: root

    // ---------- open / close ----------
    property bool open: false
    property string openScreen: ""
    property string startPage: "widgets" // which tab it opens on
    onOpenChanged: if (root.open) root.openScreen = Hyprland.focusedMonitor?.name ?? ""
    // the card opens on a spring and closes with a quick slide
    MosaicSpring { id: openSpring; response: 0.42; damping: 0.78; springBack: false; closeMs: 200; target: root.open ? 1 : 0 }

    function toggle() { root.open = !root.open; }
    function openOn(page) {
        root.startPage = page;
        root.open = true;
    }

    IpcHandler {
        target: "mosaicSettings"
        function toggle(): void { root.toggle(); }
        function widgets(): void { root.openOn("widgets"); }
        function recording(): void { root.openOn("record"); }
        function island(): void { root.openOn("island"); }
        function look(): void { root.openOn("look"); }
        function dock(): void { root.openOn("dock"); }
        function apps(): void { root.openOn("apps"); }
        function areas(): void { root.openOn("areas"); }
    }
    GlobalShortcut {
        name: "mosaicSettingsToggle"
        description: "Abre e fecha as configurações do Mosaic OS"
        onPressed: root.toggle()
    }

    // ---------- the window ----------
    LazyLoader {
        active: root.open || openSpring.value > 0.01
        component: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === root.openScreen) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mosaicSettings"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            readonly property real v: Math.max(0, openSpring.value)
            property string page: root.startPage // the tab on show
            Component.onDestruction: root.startPage = "widgets"

            // the dim behind the card (kept under the glass threshold, so only the card is glass)
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.25 * win.v
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(1120, win.width - 80)
                height: Math.min(680, win.height - 100)
                radius: Appearance.rounding.large
                color: MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer0
                border.width: MosaicTheme.brutal ? MosaicTheme.border : 1
                border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
                opacity: win.v
                // brutal themes: a big hard shadow under the whole card
                Rectangle {
                    visible: MosaicTheme.brutal
                    z: -1
                    x: 8
                    y: 8
                    width: parent.width
                    height: parent.height
                    radius: parent.radius
                    color: MosaicTheme.shadowColor
                }
                scale: 0.94 + 0.06 * win.v
                MouseArea { anchors.fill: parent } // clicks on the card don't close it
                focus: root.open
                Keys.onEscapePressed: root.open = false
                Grain { radius: card.radius; amount: MosaicTheme.grainPicker } // film grain (retro themes)

                // ----- left column -----
                ColumnLayout {
                    id: side
                    x: 24
                    y: 24
                    width: 290
                    height: parent.height - 48
                    spacing: 14

                    RowLayout {
                        spacing: 10
                        Mascot {
                            size: 18
                            showFace: false
                        }
                        StyledText {
                            text: MosaicTheme.brutal ? "CONFIGURAÇÕES" : "Configurações"
                            font.letterSpacing: MosaicTheme.brutal ? 1.2 : 0
                            font.family: MosaicTheme.fontDisplay
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    // ----- themes: Mosaic (wallpaper colours) or a fixed palette -----
                    // two per row; more themes wrap to the next row
                    Grid {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        columns: 2
                        spacing: 8
                        Repeater {
                            model: MosaicTheme.themes
                            delegate: Rectangle {
                                id: themeCard
                                required property var modelData
                                readonly property bool on: MosaicTheme.current === modelData.id
                                // the Mosaic theme shows the live wallpaper tones
                                readonly property var swatches: modelData.swatches ?? [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colOnLayer0]
                                width: (side.width - 8) / 2
                                height: 56
                                radius: Appearance.rounding.small
                                color: modelData.base ?? Appearance.colors.colLayer1
                                border.width: on ? 2 : 1
                                border.color: MosaicTheme.brutal ? MosaicTheme.ink : on ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                                HardShadow { visible: MosaicTheme.brutal && themeCard.on }
                                scale: themeArea.pressed ? 0.95 : themeArea.containsMouse ? 1.02 : 1
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                // a little Mosaic mark painted in the theme's four tones
                                Item {
                                    id: miniMark
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    height: 26
                                    Repeater {
                                        model: [[0, 0, 56, 56], [64, 0, 24, 56], [0, 64, 56, 24], [64, 64, 24, 24]]
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            x: modelData[0] * 26 / 88
                                            y: modelData[1] * 26 / 88
                                            width: modelData[2] * 26 / 88
                                            height: modelData[3] * 26 / 88
                                            radius: MosaicTheme.r(2)
                                            color: themeCard.swatches[index]
                                        }
                                    }
                                }
                                Column {
                                    anchors.left: miniMark.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    StyledText {
                                        text: themeCard.modelData.name
                                        // in the theme's own title font, when it is installed
                                        font.family: themeCard.modelData.fontDisplay && Qt.fontFamilies().includes(themeCard.modelData.fontDisplay) ? themeCard.modelData.fontDisplay : MosaicTheme.fontUi
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: themeCard.modelData.swatches ? themeCard.modelData.swatches[3] : Appearance.colors.colOnLayer0
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: themeCard.modelData.hint
                                        font.pixelSize: 10
                                        color: themeCard.modelData.swatches ? themeCard.modelData.swatches[3] : Appearance.colors.colOnLayer0
                                        opacity: 0.65
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    id: themeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: MosaicTheme.set(themeCard.modelData.id)
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                    StyledText {
                        text: "esc fechar"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        color: Appearance.colors.colSubtext
                    }
                }

                // ----- tabs -----
                Row {
                    id: pageTabs
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    spacing: 8
                    Repeater {
                        model: [{ id: "widgets", label: "Widgets", icon: "widgets" }, { id: "record", label: "Gravação", icon: "videocam" }, { id: "island", label: "Ilha", icon: "pill" }, { id: "look", label: "Aparência", icon: "palette" }, { id: "dock", label: "Dock", icon: "dock_to_bottom" }, { id: "apps", label: "Apps", icon: "apps" }]
                        delegate: Rectangle {
                            id: pageTab
                            required property var modelData
                            readonly property bool on: win.page === modelData.id
                            implicitWidth: pageTabRow.implicitWidth + 28
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : root.softBlockOf(Appearance.colors.colPrimary))
                                : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1)
                            border.width: MosaicTheme.brutal ? (on ? MosaicTheme.border : 1) : 0
                            border.color: MosaicTheme.ink
                            Behavior on color { ColorAnimation { duration: 160 } }
                            transform: Translate { x: tabShadow.sinkShift; y: tabShadow.sinkShift }
                            HardShadow { id: tabShadow; visible: MosaicTheme.brutal && !pageTab.on; sink: pageTabArea.pressed }
                            RowLayout {
                                id: pageTabRow
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol {
                                    text: pageTab.modelData.icon
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    text: MosaicTheme.brutal ? pageTab.modelData.label.toUpperCase() : pageTab.modelData.label
                                    font.family: MosaicTheme.fontUi
                                    font.pixelSize: 14
                                    font.weight: pageTab.on ? Font.Bold : Font.Normal
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                            MouseArea {
                                id: pageTabArea
                                anchors.fill: parent
                                onClicked: win.page = pageTab.modelData.id
                            }
                        }
                    }
                }

                // ----- Widgets: the desktop widgets, each with its own switch -----
                // Each one is Config.options.background.widgets.<key>.enable: the ii
                // background shows or hides it as soon as the value changes.
                GridView {
                    id: widgetGrid
                    visible: win.page === "widgets"
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    clip: true
                    cellWidth: Math.floor(width / 2)
                    cellHeight: 92
                    interactive: false
                    model: [
                        { key: "clock", icon: "schedule", name: "Relógio", hint: "a hora grande no fundo" },
                        { key: "calendar", icon: "calendar_month", name: "Calendário", hint: "o mês com o dia de hoje" },
                        { key: "weather", icon: "partly_cloudy_day", name: "Clima", hint: "temperatura e previsão" },
                        { key: "media", icon: "music_note", name: "Música", hint: "o que está tocando" },
                        { key: "photos", icon: "photo", name: "Fotos", hint: "um porta-retratos" },
                        { key: "photos2", icon: "photo_library", name: "Fotos 2", hint: "o segundo porta-retratos" },
                        { key: "anniversary", icon: "favorite", name: "Dias juntos", hint: "o contador de dias" }
                    ]
                    delegate: Item {
                        id: wcell
                        required property var modelData
                        required property int index
                        readonly property var conf: Config.options.background.widgets[modelData.key]
                        readonly property bool on: conf?.enable ?? false
                        width: widgetGrid.cellWidth
                        height: widgetGrid.cellHeight
                        // cascade, like the wallpapers
                        property real born: 0
                        Behavior on born { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                        Timer { running: wcell.visible; interval: 60 + wcell.index * 40; onTriggered: wcell.born = 1 }
                        onVisibleChanged: if (!visible) born = 0

                        Rectangle {
                            id: wcard
                            anchors.fill: parent
                            anchors.margins: 6
                            anchors.rightMargin: 6 + MosaicTheme.shadow
                            anchors.bottomMargin: 6 + MosaicTheme.shadow
                            radius: Appearance.rounding.normal
                            opacity: wcell.born
                            scale: 0.9 + 0.1 * wcell.born
                            color: MosaicTheme.brutal ? (wcell.on ? MosaicTheme.slabRaised : MosaicTheme.slab) : (wcell.on ? root.softBlockOf(Appearance.colors.colPrimary) : Appearance.colors.colLayer1)
                            border.width: MosaicTheme.brutal ? MosaicTheme.border : 0
                            border.color: MosaicTheme.ink
                            Behavior on color { ColorAnimation { duration: 200 } }
                            transform: Translate { x: wShadow.sinkShift; y: wShadow.sinkShift }
                            HardShadow { id: wShadow; visible: MosaicTheme.brutal && wcell.on; sink: wArea.pressed }

                            Rectangle { // the icon on a little block
                                id: wIcon
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 44
                                radius: Appearance.rounding.small
                                color: wcell.on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : Appearance.colors.colPrimary) : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer2)
                                border.width: MosaicTheme.brutal ? 1.5 : 0
                                border.color: MosaicTheme.ink
                                Behavior on color { ColorAnimation { duration: 200 } }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: wcell.modelData.icon
                                    iconSize: 24
                                    fill: wcell.on ? 1 : 0
                                    color: wcell.on && !MosaicTheme.brutal ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                }
                            }
                            Column {
                                anchors.left: wIcon.right
                                anchors.leftMargin: 12
                                anchors.right: wSwitch.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                StyledText {
                                    width: parent.width
                                    text: wcell.modelData.name
                                    font.family: MosaicTheme.fontUi
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    width: parent.width
                                    text: wcell.modelData.hint
                                    font.pixelSize: 11
                                    color: Appearance.colors.colOnLayer0
                                    opacity: 0.65
                                    elide: Text.ElideRight
                                }
                            }
                            // the switch: the knob slides on a spring (square knob in brutal themes)
                            Rectangle {
                                id: wSwitch
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46
                                height: 26
                                radius: MosaicTheme.r(13)
                                color: wcell.on ? Appearance.colors.colPrimary : (MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer2)
                                border.width: MosaicTheme.brutal ? 1.5 : 0
                                border.color: MosaicTheme.ink
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: MosaicTheme.r(9)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 4 + (parent.width - width - 8) * knob.value
                                    color: wcell.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                    MosaicSpring { id: knob; response: 0.3; damping: 0.7; epsilon: 0.002; target: wcell.on ? 1 : 0; Component.onCompleted: settle(target) }
                                }
                            }
                            MouseArea {
                                id: wArea
                                anchors.fill: parent
                                onClicked: if (wcell.conf) wcell.conf.enable = !wcell.on
                            }
                        }
                    }
                }

                // ----- Gravação: resolution and fps of the screen recorder -----
                // Config.options.screenRecord.resolution / .fps, read by record.sh
                // (wf-recorder -F scale=-2:<height> and -r <fps>) on the next recording.
                Flickable {
                    id: recordPage
                    visible: win.page === "record"
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    clip: true
                    contentHeight: recordColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property var conf: Config.options.screenRecord
                    Column {
                        id: recordColumn
                        width: parent.width
                        spacing: 22
                        RecordGroup {
                            title: "Resolução"
                            hint: "A altura do vídeo; a largura acompanha a proporção da tela."
                            options: [
                                { value: "native", label: "Nativa", sub: "como a tela" },
                                { value: "1440", label: "1440p", sub: "2K" },
                                { value: "1080", label: "1080p", sub: "Full HD" },
                                { value: "720", label: "720p", sub: "leve" }
                            ]
                            current: recordPage.conf.resolution
                            onPicked: value => recordPage.conf.resolution = value
                        }
                        RecordGroup {
                            title: "Quadros por segundo"
                            hint: "Mais fps = movimento mais liso e arquivo maior."
                            options: [
                                { value: 30, label: "30", sub: "fps" },
                                { value: 60, label: "60", sub: "fps" },
                                { value: 120, label: "120", sub: "fps" },
                                { value: 144, label: "144", sub: "fps" }
                            ]
                            current: recordPage.conf.fps
                            onPicked: value => recordPage.conf.fps = value
                        }
                        RecordGroup {
                            title: "Som"
                            hint: "O que entra no áudio do vídeo."
                            options: [
                                { value: "system", label: "PC", sub: "o que está tocando" },
                                { value: "mic", label: "Mic", sub: "microfone" },
                                { value: "none", label: "Mudo", sub: "sem som" }
                            ]
                            current: recordPage.conf.audio
                            onPicked: value => recordPage.conf.audio = value
                        }
                        // where the videos go, and how to record
                        Rectangle {
                            width: parent.width - MosaicTheme.shadow
                            height: recInfo.implicitHeight + 28
                            radius: Appearance.rounding.normal
                            color: MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer1
                            border.width: MosaicTheme.brutal ? 1.5 : 0
                            border.color: MosaicTheme.ink
                            Column {
                                id: recInfo
                                x: 16
                                y: 14
                                width: parent.width - 32
                                spacing: 6
                                Row {
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "folder"
                                        iconSize: 18
                                        color: Appearance.colors.colOnLayer0
                                    }
                                    StyledText {
                                        text: recordPage.conf.savePath
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 12
                                        color: Appearance.colors.colOnLayer0
                                    }
                                }
                                StyledText {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: "Para gravar: o botão Gravar no painel da ilha grava a tela inteira; clique de novo para parar. As mudanças valem a partir da próxima gravação."
                                    font.pixelSize: 11
                                    color: Appearance.colors.colOnLayer0
                                    opacity: 0.7
                                }
                            }
                        }
                    }
                }

                // ----- Ilha / Aparência / Dock: glass, chromatic aberration, transparency, darkness -----
                // Config.options.mosaicIsland / mosaicWidgets (both sidebars and the
                // desktop widgets) / mosaicDock. Transparency and darkness change them right
                // away; glass and chromatic aberration rewrite their hyprglass presets
                // and reload Hyprland (MosaicGlass). Retro themes add film grain sliders.
                GlassPage {
                    visible: win.page === "island"
                    conf: Config.options.mosaicIsland
                    where: "a ilha"
                    grains: [{ key: "grain", title: "Ilha" }]
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18 + MosaicTheme.shadow
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 20
                }
                GlassPage {
                    visible: win.page === "look"
                    conf: Config.options.mosaicWidgets
                    where: "os widgets"
                    intro: "Vale para as duas laterais e os widgets do fundo. A ilha e a dock têm abas próprias."
                    grains: [
                        { key: "grainSidebars", title: "Laterais" },
                        { key: "grainDesktop", title: "Widgets do fundo" },
                        { key: "grainPicker", title: "Esta janela" }
                    ]
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18 + MosaicTheme.shadow
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 20
                }
                GlassPage {
                    visible: win.page === "dock"
                    conf: Config.options.mosaicDock
                    where: "a dock"
                    grains: [{ key: "grain", title: "Dock" }]
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18 + MosaicTheme.shadow
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 20
                }

                // ----- Apps: film grain on every app, terminal included -----
                // Config.options.mosaicApps, drawn by Hyprland (MosaicScreenGrain)
                Column {
                    id: appsPage
                    visible: win.page === "apps"
                    readonly property var conf: Config.options.mosaicApps
                    anchors.left: side.right
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 18 + MosaicTheme.shadow
                    anchors.top: pageTabs.bottom
                    anchors.topMargin: 20
                    spacing: 22
                    StyledText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: MosaicTheme.grain > 0
                            ? "Granulado de filme em todos os apps: terminal, navegador, Steam... É o Hyprland que passa o grão na tela inteira. Enquanto ele estiver ligado, o shell desliga o grão dele, para não ficar dobrado."
                            : "Só os temas com granulado de filme (como o Horizonte) usam esta aba."
                        font.pixelSize: 12
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.8
                    }
                    TuneSlider {
                        visible: MosaicTheme.grain > 0
                        title: "Granulado dos apps"
                        hint: "0 desliga e devolve o grão próprio do shell."
                        from: 0
                        to: 2
                        value: appsPage.conf.grain
                        shown: Math.round(value * 100) + "%"
                        onMoved: v => appsPage.conf.grain = v
                    }
                    RecordGroup {
                        visible: MosaicTheme.grain > 0
                        title: "Em tela cheia"
                        hint: "Jogos e vídeo em tela cheia. Sem o grão, a imagem vai direto da GPU para o monitor, o que é mais leve em jogo."
                        options: [
                            { value: true, label: "Desliga", sub: "volta ao sair" },
                            { value: false, label: "Fica", sub: "sempre" }
                        ]
                        current: appsPage.conf.fullscreenOff
                        onPicked: value => appsPage.conf.fullscreenOff = value
                    }
                }

            }
        }
    }

    function softBlockOf(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.32); }

    // A row of choices with a title (the Gravação tab): the chosen one stands up
    component RecordGroup: Column {
        id: group
        required property string title
        property string hint: ""
        required property var options
        property var current
        signal picked(var value)
        width: parent ? parent.width : 0
        spacing: 10
        StyledText {
            text: MosaicTheme.brutal ? group.title.toUpperCase() : group.title
            font.family: MosaicTheme.fontUi
            font.pixelSize: 15
            font.weight: MosaicTheme.brutal ? Font.Black : Font.DemiBold
            font.letterSpacing: MosaicTheme.brutal ? 1.2 : 0
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            visible: group.hint !== ""
            text: group.hint
            font.pixelSize: 11
            color: Appearance.colors.colOnLayer0
            opacity: 0.65
        }
        Row {
            spacing: 10 + MosaicTheme.shadow
            Repeater {
                model: group.options
                delegate: Rectangle {
                    id: opt
                    required property var modelData
                    readonly property bool on: String(group.current) === String(modelData.value)
                    width: 110
                    height: 64
                    radius: Appearance.rounding.normal
                    color: on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.32))
                        : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1)
                    border.width: MosaicTheme.brutal ? (on ? MosaicTheme.border : 1) : (on ? 2 : 0)
                    border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colPrimary
                    Behavior on color { ColorAnimation { duration: 180 } }
                    transform: Translate { x: optShadow.sinkShift; y: optShadow.sinkShift }
                    HardShadow { id: optShadow; visible: MosaicTheme.brutal && opt.on; sink: optArea.pressed }
                    scale: !MosaicTheme.brutal && optArea.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    Column {
                        anchors.centerIn: parent
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: opt.modelData.label
                            font.family: MosaicTheme.fontDisplay
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: opt.modelData.sub
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.65
                        }
                    }
                    MouseArea {
                        id: optArea
                        anchors.fill: parent
                        onClicked: group.picked(opt.modelData.value)
                    }
                }
            }
        }
    }

    // A labelled slider with its value on the right (the Ilha tab). The fill
    // follows the value on a spring; drag, click or scroll to change it.
    component TuneSlider: Column {
        id: tune
        required property string title
        property string hint: ""
        property real from: 0
        property real to: 1
        property real value: 0
        property string shown: ""
        signal moved(real v)
        width: parent ? parent.width : 0
        spacing: 8
        readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
        Row {
            width: parent.width
            StyledText {
                width: parent.width - valueText.width
                text: MosaicTheme.brutal ? tune.title.toUpperCase() : tune.title
                font.family: MosaicTheme.fontUi
                font.pixelSize: 15
                font.weight: MosaicTheme.brutal ? Font.Black : Font.DemiBold
                font.letterSpacing: MosaicTheme.brutal ? 1.2 : 0
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                id: valueText
                text: tune.shown
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Appearance.colors.colPrimary
            }
        }
        StyledText {
            visible: tune.hint !== ""
            text: tune.hint
            font.pixelSize: 11
            color: Appearance.colors.colOnLayer0
            opacity: 0.65
        }
        Item {
            width: parent.width
            height: 32
            Rectangle {
                id: tuneTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: MosaicTheme.brutal ? 18 : 12
                radius: MosaicTheme.r(6)
                color: MosaicTheme.brutal ? MosaicTheme.slab : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.86)
                border.width: MosaicTheme.brutal ? 1.5 : 0
                border.color: MosaicTheme.ink
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(height, parent.width * tuneFill.value)
                    color: Appearance.colors.colPrimary
                    border.width: parent.border.width
                    border.color: parent.border.color
                    MosaicSpring { id: tuneFill; response: 0.25; damping: 0.85; epsilon: 0.002; target: tune.frac; Component.onCompleted: settle(target) }
                }
            }
            MouseArea {
                anchors.fill: parent
                function set(mx) { tune.moved(tune.from + Math.max(0, Math.min(1, mx / width)) * (tune.to - tune.from)); }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => { if (pressed) set(mouse.x); }
                onWheel: wheel => tune.moved(Math.max(tune.from, Math.min(tune.to, tune.value + (wheel.angleDelta.y > 0 ? 1 : -1) * (tune.to - tune.from) / 20)))
            }
        }
    }

    // The look settings page (Ilha, Aparência and Dock tabs): one set of sliders for `conf`.
    // With a retro theme (Horizonte), a "Granulado de filme" group follows, one
    // slider per part in `grains` ({ key: the conf property, title }), two per row.
    component GlassPage: Column {
        id: gp
        required property var conf
        required property string where // "a ilha" / "os widgets" / "a dock", for the texts
        property string intro: ""
        property var grains: []
        spacing: MosaicTheme.retro ? 10 : 22 // tighter when the grain group needs the room
        StyledText {
            visible: gp.intro !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: gp.intro
            font.pixelSize: 12
            color: Appearance.colors.colOnLayer0
            opacity: 0.8
        }
        TuneSlider {
            title: "Potência do liquid glass"
            hint: "Lente, refração e brilho. 0 desliga o vidro."
            from: 0
            to: 2
            value: gp.conf.glass
            shown: Math.round(value * 100) + "%"
            onMoved: v => gp.conf.glass = v
        }
        TuneSlider {
            title: "Aberração cromática"
            hint: "As bordas de arco-íris do vidro."
            from: 0
            to: 2
            value: gp.conf.chroma
            shown: Math.round(value * 100) + "%"
            onMoved: v => gp.conf.chroma = v
        }
        TuneSlider {
            title: "Transparência"
            hint: `Quanto dá para ver através d${gp.where}.`
            from: 0
            to: 1
            value: 1 - gp.conf.opacity
            shown: Math.round(value * 100) + "%"
            onMoved: v => gp.conf.opacity = 1 - v
        }
        TuneSlider {
            title: "Escuridão"
            hint: "Da cor do tema até o preto."
            from: 0
            to: 1
            value: gp.conf.darkness
            shown: Math.round(value * 100) + "%"
            onMoved: v => gp.conf.darkness = v
        }
        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            text: `Transparência e escuridão mudam ${gp.where} na hora. Vidro e aberração levam cerca de 1 s: o Hyprland recarrega para aplicar.`
            font.pixelSize: 11
            color: Appearance.colors.colOnLayer0
            opacity: 0.65
        }
        // film grain: only themes that have it (retro, like Horizonte)
        StyledText {
            visible: MosaicTheme.retro
            text: "Granulado de filme"
            font.family: MosaicTheme.fontDisplay
            font.pixelSize: 18
            color: Appearance.colors.colOnLayer0
        }
        // with the apps' grain on, the shell's own grain steps aside (no double grain)
        StyledText {
            visible: MosaicTheme.retro && MosaicScreenGrain.wanted
            width: parent.width
            wrapMode: Text.Wrap
            text: "Pausado: o granulado dos apps (aba Apps) já cobre a tela toda. Ponha ele em 0 para usar estes."
            font.pixelSize: 11
            color: Appearance.colors.colPrimary
        }
        Grid {
            visible: MosaicTheme.retro
            width: parent.width
            columns: 2
            columnSpacing: 24
            rowSpacing: 4
            Repeater {
                model: gp.grains
                delegate: TuneSlider {
                    required property var modelData
                    width: (gp.width - 24) / 2
                    title: modelData.title
                    from: 0
                    to: 2
                    value: gp.conf[modelData.key]
                    shown: Math.round(value * 100) + "%"
                    onMoved: v => gp.conf[modelData.key] = v
                }
            }
        }
    }
}
