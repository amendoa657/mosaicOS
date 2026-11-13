pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mosaic.island
import qs.modules.ii.sidebarRight.calendar
import qs.modules.ii.sidebarRight.notifications

// The Mosaic OS right sidebar: a full-height column glued to the right edge
// (Super+N, the dock's status), in the theme's style (glass in Mosaic, a solid
// brutalist slab in Gruvbox). Top to bottom:
// - greeting + date, and buttons for the wallpaper carousel, the Mosaic settings (themes), the ii settings and power
// - quick toggles (Wi-Fi, Bluetooth, do not disturb, night light, caffeine, mic)
// - volume and brightness sliders
// - the phone (KDE Connect): battery, ring it, ping, send a file
// - the calendar (the ii's) and the notification history (the ii's list)
// It slides in from the edge on a spring; Esc or a click outside closes it.
// In the Mosaic theme it is mosaic-ui all through (`mo`): a dark column over
// the dot field (MoDots), keys that sink (MoTecla), the usual icons and the UI
// font, sliders made of blocks and a calendar of tiles; no glass.
Scope {
    id: root
    readonly property bool mo: MosaicTheme.current === "mosaic"
    onOpenChanged: if (open) rightDots.shuffle()
    readonly property real sidebarWidth: 440
    readonly property bool open: GlobalStates.sidebarRightOpen
    readonly property string phoneId: "fe08adfa88664ff488cafe2d338d96fd"
    readonly property string phonePath: "/modules/kdeconnect/devices/" + root.phoneId

    // 0 = outside the screen, 1 = in place
    MosaicSpring { id: slide; response: 0.42; damping: 0.86; springBack: false; closeMs: 220; target: root.open ? 1 : 0 }

    // Click outside closes it: a transparent window covering the screen, under
    // the sidebar (Top layer; the sidebar is on Overlay). A click on it closes
    // the sidebar. (Hyprland's focus grab was dropping on its own right after the
    // sidebar opened, which closed it at the first click inside.)
    PanelWindow {
        visible: root.open
        screen: panel.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:sidebarCatcher"
        WlrLayershell.layer: WlrLayer.Top
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: GlobalStates.sidebarRightOpen = false
        }
    }

    PanelWindow {
        id: panel
        visible: root.open || slide.value > 0.005
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        exclusiveZone: 0
        implicitWidth: root.sidebarWidth + MosaicTheme.shadow + 4
        color: "transparent"
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.layer: WlrLayer.Overlay // above the click catcher
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors {
            top: true
            right: true
            bottom: true
        }
        // What takes the mouse: a still item the size of the column. The column itself
        // slides in with a transform, and Region doesn't follow transforms: masking
        // the column left the input region where the column was born (off the
        // screen), so clicks went through the sidebar to the catcher and closed it.
        Item {
            id: hitArea
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.sidebarWidth
        }
        mask: Region { item: hitArea }

        // brutal themes: the hard shadow falls on the inside (left) of the column
        Rectangle {
            visible: MosaicTheme.brutal
            x: column.x - MosaicTheme.shadow
            y: MosaicTheme.shadow
            width: column.width
            height: column.height
            color: MosaicTheme.shadowColor
            radius: column.radius
            transform: Translate { x: column.offset }
        }

        Rectangle {
            id: column
            readonly property real offset: (1 - slide.value) * (root.sidebarWidth + 20)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.sidebarWidth
            transform: Translate { x: column.offset }
            radius: root.mo ? 18 : Appearance.rounding.large
            // the Aparência tab's surface (darkness and opacity), shared with the island;
            // Mosaic: solid and dark, the dots show on it
            color: root.mo ? Appearance.m3colors.m3surfaceContainerLowest
                : MosaicTheme.brutal ? MosaicTheme.slab : MosaicTheme.widgetFill(Appearance.colors.colLayer0)
            border.width: MosaicTheme.brutal ? MosaicTheme.border + 1 : 1
            border.color: root.mo ? Qt.alpha(Appearance.m3colors.m3outlineVariant, 0.6)
                : MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
            focus: root.open
            Keys.onEscapePressed: GlobalStates.sidebarRightOpen = false
            // keep the corners on the screen edge square: only the inner side is round
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.radius
                color: parent.color
                border.width: 0
                Rectangle { anchors.top: parent.top; width: parent.width; height: column.border.width; color: column.border.color }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: column.border.width; color: column.border.color }
            }
            // film grain (retro themes). It runs one radius past the screen edge, where
            // the window cuts it, so only the inner corners are round, like the column.
            Grain {
                anchors.fill: undefined
                width: column.width + column.radius
                height: column.height
                radius: column.radius
                amount: MosaicTheme.grainSidebars
            }
            // Mosaic: the still dot field, clear of the rounded inner corners
            MoDots {
                id: rightDots
                visible: root.mo
                anchors.fill: parent
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                anchors.leftMargin: 6
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                anchors.rightMargin: 16 + MosaicTheme.shadow
                anchors.bottomMargin: 16 + MosaicTheme.shadow
                spacing: 12 + MosaicTheme.shadow

                // ---------- header ----------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Mascot {
                        size: 26
                        showFace: false
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: {
                                const h = DateTime.clock.date.getHours();
                                const g = h < 5 ? "Boa madrugada" : h < 12 ? "Bom dia" : h < 18 ? "Boa tarde" : "Boa noite";
                                return MosaicTheme.brutal ? g.toUpperCase() : g;
                            }
                            font.family: MosaicTheme.fontDisplay
                            font.pixelSize: 18
                            font.weight: MosaicTheme.brutal ? Font.Black : Font.Bold
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: DateTime.longDate
                            font.family: MosaicTheme.fontUi
                            font.pixelSize: root.mo ? 10 : 12
                            font.letterSpacing: root.mo ? 1.2 : 0
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.7
                        }
                    }
                    // the header's buttons, close together
                    RowLayout {
                    spacing: 2
                    IconKey {
                        icon: "wallpaper"
                        pixel: "imagem"
                        tip: "Trocar papel de parede"
                        onClicked: {
                            GlobalStates.sidebarRightOpen = false;
                            GlobalStates.wallpaperSelectorOpen = true;
                        }
                    }
                    IconKey {
                        icon: "palette"
                        pixel: "mosaico"
                        tip: "Temas e aparência do Mosaic"
                        onClicked: {
                            GlobalStates.sidebarRightOpen = false;
                            Quickshell.execDetached(["qs", "-c", "mosaic", "ipc", "call", "mosaicSettings", "toggle"]);
                        }
                    }
                    IconKey {
                        icon: "settings"
                        pixel: "config"
                        tip: "Configurações"
                        onClicked: {
                            GlobalStates.sidebarRightOpen = false;
                            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
                        }
                    }
                    IconKey {
                        icon: "power_settings_new"
                        pixel: "energia"
                        tip: "Desligar, reiniciar…"
                        onClicked: {
                            GlobalStates.sidebarRightOpen = false;
                            GlobalStates.sessionOpen = true;
                        }
                    }
                    }
                }

                // ---------- quick toggles ----------
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 8 + MosaicTheme.shadow
                    columnSpacing: 8 + MosaicTheme.shadow
                    Toggle {
                        icon: Network.materialSymbol
                        label: "Wi-Fi"
                        pixel: "wifi"
                        status: Network.wifiStatus !== "disabled" ? (Network.networkName || "ligado") : "desligado"
                        on: Network.wifiStatus !== "disabled"
                        onClicked: Network.toggleWifi()
                        onAltClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.network])
                    }
                    Toggle {
                        icon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        label: "Bluetooth"
                        pixel: "bluetooth"
                        status: BluetoothStatus.connected ? "conectado" : BluetoothStatus.enabled ? "ligado" : "desligado"
                        on: BluetoothStatus.enabled
                        onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        onAltClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.bluetooth])
                    }
                    Toggle {
                        icon: Notifications.silent ? "notifications_paused" : "notifications_active"
                        label: "Silêncio"
                        pixel: "sino"
                        status: Notifications.silent ? "ligado" : "desligado"
                        on: Notifications.silent
                        onClicked: Notifications.silent = !Notifications.silent
                    }
                    Toggle {
                        icon: "nightlight"
                        label: "Luz noturna"
                        pixel: "lua"
                        status: Hyprsunset.temperatureActive ? "ligada" : "desligada"
                        on: Hyprsunset.temperatureActive
                        onClicked: Hyprsunset.toggleTemperature()
                    }
                    Toggle {
                        icon: "coffee"
                        label: "Café"
                        pixel: "cafe"
                        status: Idle.inhibit ? "tela acordada" : "desligado"
                        on: Idle.inhibit
                        onClicked: Idle.toggleInhibit()
                    }
                    Toggle {
                        readonly property bool muted: Audio.source?.audio?.muted ?? false
                        icon: muted ? "mic_off" : "mic"
                        label: "Microfone"
                        pixel: "microfone"
                        status: muted ? "mudo" : "ligado"
                        on: !muted
                        onClicked: if (Audio.source?.audio) Audio.source.audio.muted = !Audio.source.audio.muted
                    }
                }

                // ---------- sliders ----------
                Section {
                    Layout.fillWidth: true
                    implicitHeight: sliders.implicitHeight + 24
                    ColumnLayout {
                        id: sliders
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        Slide {
                            readonly property bool muted: Audio.sink?.audio?.muted ?? false
                            icon: muted ? "volume_off" : "volume_up"
                            pixel: "volume"
                            value: Audio.sink?.audio?.volume ?? 0
                            onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.volume = v; }
                            onIconClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                        }
                        Slide {
                            readonly property var monitor: Brightness.getMonitorForScreen(panel.screen)
                            icon: "light_mode"
                            pixel: "sol"
                            value: monitor?.brightness ?? 0
                            onMoved: v => monitor?.setBrightness(v)
                        }
                    }
                }

                // ---------- phone ----------
                Section {
                    id: phoneBox
                    Layout.fillWidth: true
                    implicitHeight: 74
                    property int charge: -1
                    property bool charging: false
                    property string phoneName: "Celular"
                    // asked once each time the sidebar opens (cheap, no polling)
                    Process {
                        id: phoneInfo
                        running: root.open
                        command: ["sh", "-c", `qdbus org.kde.kdeconnect ${root.phonePath} org.kde.kdeconnect.device.name; qdbus org.kde.kdeconnect ${root.phonePath}/battery org.kde.kdeconnect.device.battery.charge; qdbus org.kde.kdeconnect ${root.phonePath}/battery org.kde.kdeconnect.device.battery.isCharging`]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const l = this.text.split("\n");
                                if (l[0]) phoneBox.phoneName = l[0].trim();
                                const c = parseInt(l[1]);
                                phoneBox.charge = isNaN(c) ? -1 : c;
                                phoneBox.charging = (l[2] ?? "").trim() === "true";
                            }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        PhoneBattery {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 22
                            visible: phoneBox.charge >= 0
                            value: phoneBox.charge / 100
                            charging: phoneBox.charging
                        }
                        MaterialSymbol {
                            visible: phoneBox.charge < 0
                            text: "mobile_off"
                            iconSize: 24
                            color: Appearance.colors.colOnLayer0
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: phoneBox.phoneName
                                font.family: MosaicTheme.fontUi
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: phoneBox.charge >= 0 ? `${phoneBox.charge}%${phoneBox.charging ? " · carregando" : ""}` : "desconectado"
                                font.family: MosaicTheme.fontUi
                                font.pixelSize: root.mo ? 10 : 11
                                color: Appearance.colors.colOnLayer0
                                opacity: 0.7
                            }
                        }
                        IconKey {
                            enabled: phoneBox.charge >= 0
                            icon: "ring_volume"
                            pixel: "sino"
                            tip: "Tocar o celular"
                            onClicked: Quickshell.execDetached(["qdbus", "org.kde.kdeconnect", root.phonePath + "/findmyphone", "org.kde.kdeconnect.device.findmyphone.ring"])
                        }
                        IconKey {
                            enabled: phoneBox.charge >= 0
                            icon: "notifications"
                            pixel: "alerta"
                            tip: "Ping"
                            onClicked: Quickshell.execDetached(["qdbus", "org.kde.kdeconnect", root.phonePath + "/ping", "org.kde.kdeconnect.device.ping.sendPing"])
                        }
                        IconKey {
                            enabled: phoneBox.charge >= 0
                            icon: "upload_file"
                            pixel: "pasta"
                            tip: "Enviar arquivo"
                            onClicked: {
                                GlobalStates.sidebarRightOpen = false;
                                Quickshell.execDetached(["sh", "-c", `f=$(zenity --file-selection --title='Enviar para o celular') && qdbus org.kde.kdeconnect ${root.phonePath}/share org.kde.kdeconnect.device.share.shareUrl "file://$f"`]);
                            }
                        }
                    }
                }

                // ---------- calendar ----------
                Section {
                    Layout.fillWidth: true
                    implicitHeight: root.mo ? moCalendar.implicitHeight + 24 : 336
                    CalendarWidget {
                        visible: !root.mo
                        anchors.fill: parent
                        anchors.margins: 8
                    }
                    MoCalendar {
                        id: moCalendar
                        visible: root.mo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                    }
                }

                // ---------- notifications ----------
                Section {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StyledText {
                        id: notifTitle
                        x: 14
                        y: 12
                        text: MosaicTheme.brutal ? "NOTIFICAÇÕES" : "Notificações"
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: root.mo ? 11 : 13
                        font.weight: MosaicTheme.brutal ? Font.Black : root.mo ? Font.Bold : Font.DemiBold
                        font.letterSpacing: MosaicTheme.brutal ? 1.2 : 0
                        color: MosaicTheme.brutal ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                        rotation: MosaicTheme.tilt
                    }
                    NotificationList {
                        anchors.top: notifTitle.bottom
                        anchors.topMargin: 6
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "sidebarRight"
        function toggle(): void { GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen; }
        function close(): void { GlobalStates.sidebarRightOpen = false; }
        function open(): void { GlobalStates.sidebarRightOpen = true; }
    }
    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Abre e fecha a lateral direita"
        onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Abre a lateral direita"
        onPressed: GlobalStates.sidebarRightOpen = true
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Fecha a lateral direita"
        onPressed: GlobalStates.sidebarRightOpen = false
    }

    // A block of the column, in the theme's style. Mosaic: a solid tile with a
    // hairline and a soft object shadow under it, like the desk's widgets.
    component Section: Rectangle {
        radius: root.mo ? 14 : Appearance.rounding.normal
        color: root.mo ? Appearance.m3colors.m3surfaceContainer
            : MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1
        border.width: root.mo ? 1 : MosaicTheme.border
        border.color: root.mo ? Qt.alpha(Appearance.m3colors.m3outlineVariant, 0.5) : MosaicTheme.ink
        HardShadow {}
        Rectangle { // the object shadow (Mosaic), drawn once
            visible: root.mo
            z: -1
            x: 0; y: 3
            width: parent.width; height: parent.height
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.35)
        }
    }

    // A quick toggle: icon, name and state; on = coloured. Right click: its settings.
    // Mosaic: a key that sinks when pressed, its face the primary colour when on.
    component Toggle: Rectangle {
        id: tg
        required property string icon
        required property string label
        property string pixel: ""
        property string status: ""
        property bool on: false
        signal clicked()
        signal altClicked()
        Layout.fillWidth: true
        implicitHeight: root.mo ? 68 : 64
        radius: Appearance.rounding.normal
        color: root.mo ? "transparent"
            : on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.32))
            : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1)
        border.width: root.mo ? 0 : MosaicTheme.border
        border.color: MosaicTheme.ink
        Behavior on color { ColorAnimation { duration: 180 } }
        transform: Translate { x: tgShadow.sinkShift; y: tgShadow.sinkShift }
        HardShadow { id: tgShadow; visible: !root.mo; sink: tgArea.pressed }
        scale: !MosaicTheme.brutal && !root.mo && tgArea.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        ColumnLayout {
            visible: !root.mo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            MaterialSymbol {
                text: tg.icon
                iconSize: 20
                fill: tg.on ? 1 : 0
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                text: tg.label
                font.family: MosaicTheme.fontUi
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: tg.status
                font.pixelSize: 10
                color: Appearance.colors.colOnLayer0
                opacity: 0.65
                elide: Text.ElideRight
            }
        }
        MoTecla {
            id: tgKey
            visible: root.mo
            anchors.fill: parent
            on: tg.on
            down: tgArea.pressed
            hovered: tgArea.containsMouse
            MaterialSymbol {
                x: 12; y: 10
                text: tg.icon
                iconSize: 20
                fill: tg.on ? 1 : 0
                color: tgKey.ink
            }
            StyledText {
                x: 12; y: 33
                width: parent.width - 20
                text: tg.label
                font.family: MosaicTheme.fontUi
                font.pixelSize: 12
                font.weight: Font.Bold
                                color: tgKey.ink
                elide: Text.ElideRight
            }
            StyledText {
                x: 12; y: 49
                width: parent.width - 20
                text: tg.status
                font.family: MosaicTheme.fontUi
                font.pixelSize: 10
                color: tgKey.ink
                opacity: 0.7
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: tgArea
            anchors.fill: parent
            hoverEnabled: root.mo
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.RightButton ? tg.altClicked() : tg.clicked()
        }
    }

    // A slider: icon (click = its own action) and a track that fills on a spring.
    // Mosaic: the track is a row of blocks, lit up to the value.
    component Slide: RowLayout {
        id: sl
        required property string icon
        property string pixel: ""
        property real value: 0
        signal moved(real v)
        signal iconClicked()
        spacing: 10
        IconKey {
            icon: sl.icon
            pixel: sl.pixel
            onClicked: sl.iconClicked()
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 28
            Rectangle {
                id: track
                visible: !root.mo
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: MosaicTheme.brutal ? 16 : 10
                radius: MosaicTheme.r(5)
                color: MosaicTheme.brutal ? MosaicTheme.slab : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
                border.width: MosaicTheme.brutal ? 1.5 : 0
                border.color: MosaicTheme.ink
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(height, parent.width * fill.value)
                    color: Appearance.colors.colPrimary
                    border.width: parent.border.width
                    border.color: parent.border.color
                    MosaicSpring { id: fill; response: 0.25; damping: 0.85; epsilon: 0.002; target: Math.max(0, Math.min(1, sl.value)); Component.onCompleted: settle(target) }
                }
            }
            // Mosaic: 20 blocks; the lit ones are the value
            Row {
                id: blocks
                visible: root.mo
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 3
                readonly property int count: 20
                readonly property real cell: (width - spacing * (count - 1)) / count
                readonly property int lit: Math.round(Math.max(0, Math.min(1, sl.value)) * count)
                Repeater {
                    model: blocks.count
                    Rectangle {
                        required property int index
                        width: blocks.cell
                        height: 14
                        radius: 3
                        color: index < blocks.lit ? Appearance.m3colors.m3primary : Appearance.m3colors.m3surfaceContainerHighest
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                function set(mx) { sl.moved(Math.max(0, Math.min(1, mx / width))); }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => { if (pressed) set(mouse.x); }
                onWheel: wheel => sl.moved(Math.max(0, Math.min(1, sl.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        StyledText {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(sl.value * 100)
            font.family: MosaicTheme.fontUi
            font.pixelSize: 11
            color: Appearance.colors.colOnLayer0
        }
    }

    // A small square key with an icon. Mosaic: a small key that sinks, with a
    // pixel symbol.
    component IconKey: Rectangle {
        id: key
        required property string icon
        property string pixel: ""
        property string tip: ""
        signal clicked()
        implicitWidth: 36
        implicitHeight: root.mo ? 38 : 36
        radius: Appearance.rounding.small
        opacity: enabled ? 1 : 0.4
        color: root.mo ? "transparent"
            : keyArea.containsMouse ? (MosaicTheme.brutal ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.88))
            : (MosaicTheme.brutal ? MosaicTheme.slab : "transparent")
        border.width: MosaicTheme.brutal ? 1.5 : 0
        border.color: MosaicTheme.ink
        transform: Translate { x: keyShadow.sinkShift; y: keyShadow.sinkShift }
        HardShadow { id: keyShadow; visible: !root.mo; size: 2; sink: keyArea.pressed }
        MaterialSymbol {
            visible: !root.mo
            anchors.centerIn: parent
            text: key.icon
            iconSize: 20
            color: Appearance.colors.colOnLayer0
        }
        MoTecla {
            id: smallKey
            visible: root.mo
            anchors.fill: parent
            depth: 3
            radius: 8
            down: keyArea.pressed
            hovered: keyArea.containsMouse
            MaterialSymbol {
                anchors.centerIn: parent
                text: key.icon
                iconSize: 20
                color: smallKey.ink
            }
        }
        MouseArea {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: key.clicked()
        }
        StyledToolTip {
            extraVisibleCondition: key.tip !== "" && keyArea.containsMouse
            text: key.tip
        }
    }

    // The calendar in the Mosaic theme: the month in mono capitals, arrows on
    // small keys, and a 7 × 6 grid of tiles; today is a key in the primary colour.
    // A click on the month comes back to the current one.
    component MoCalendar: ColumnLayout {
        id: cal
        property int monthOffset: 0
        readonly property date today: DateTime.clock.date
        readonly property date shown: new Date(cal.today.getFullYear(), cal.today.getMonth() + cal.monthOffset, 1)
        readonly property var days: {
            const first = cal.shown;
            const lead = (first.getDay() + 6) % 7; // weeks start on Monday
            const out = [];
            for (let i = 0; i < 42; i++)
                out.push(new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
            return out;
        }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            StyledText {
                Layout.fillWidth: true
                text: Qt.locale("pt_BR").standaloneMonthName(cal.shown.getMonth()) + " " + cal.shown.getFullYear()
                font.family: MosaicTheme.fontUi
                font.pixelSize: 13
                font.weight: Font.Bold
                                color: Appearance.m3colors.m3onSurface
                MouseArea { anchors.fill: parent; onClicked: cal.monthOffset = 0 }
            }
            Repeater {
                model: [{ t: "‹", d: -1 }, { t: "›", d: 1 }]
                MoTecla {
                    id: arrow
                    required property var modelData
                    implicitWidth: 30
                    implicitHeight: 28
                    depth: 3
                    radius: 7
                    down: arrowArea.pressed
                    hovered: arrowArea.containsMouse
                    StyledText {
                        anchors.centerIn: parent
                        text: arrow.modelData.t
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: arrow.ink
                    }
                    MouseArea {
                        id: arrowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: cal.monthOffset += arrow.modelData.d
                    }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4
            Repeater {
                model: ["S", "T", "Q", "Q", "S", "S", "D"]
                StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: MosaicTheme.fontUi
                    font.pixelSize: 11
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }
            Repeater {
                model: cal.days
                MoTecla {
                    id: day
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === cal.shown.getMonth()
                    readonly property bool isToday: modelData.toDateString() === cal.today.toDateString()
                    Layout.fillWidth: true
                    implicitHeight: 30
                    depth: day.isToday ? 3 : 0
                    radius: 6
                    on: day.isToday
                    face: day.isToday ? Appearance.m3colors.m3primary
                        : day.inMonth ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"
                    StyledText {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 13
                        font.weight: day.isToday ? Font.Bold : Font.Normal
                        color: day.isToday ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurface
                        opacity: day.inMonth ? 1 : 0.35
                    }
                }
            }
        }
    }
}
