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
// - greeting + date, settings and power buttons
// - quick toggles (Wi-Fi, Bluetooth, do not disturb, night light, caffeine, mic)
// - volume and brightness sliders
// - the phone (KDE Connect): battery, ring it, ping, send a file
// - the calendar (the ii's) and the notification history (the ii's list)
// It slides in from the edge on a spring; Esc or a click outside closes it.
Scope {
    id: root
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
            radius: Appearance.rounding.large
            color: MosaicTheme.brutal ? MosaicTheme.slab : Appearance.colors.colLayer0
            border.width: MosaicTheme.brutal ? MosaicTheme.border + 1 : 1
            border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
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
                        spacing: 0
                        StyledText {
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
                            text: DateTime.longDate
                            font.pixelSize: 12
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.7
                        }
                    }
                    IconKey {
                        icon: "settings"
                        tip: "Configurações"
                        onClicked: {
                            GlobalStates.sidebarRightOpen = false;
                            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
                        }
                    }
                    IconKey {
                        icon: "power_settings_new"
                        tip: "Desligar, reiniciar…"
                        onClicked: {
                            GlobalStates.sidebarRightOpen = false;
                            GlobalStates.sessionOpen = true;
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
                        status: Network.wifiStatus !== "disabled" ? (Network.networkName || "ligado") : "desligado"
                        on: Network.wifiStatus !== "disabled"
                        onClicked: Network.toggleWifi()
                        onAltClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.network])
                    }
                    Toggle {
                        icon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        label: "Bluetooth"
                        status: BluetoothStatus.connected ? "conectado" : BluetoothStatus.enabled ? "ligado" : "desligado"
                        on: BluetoothStatus.enabled
                        onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        onAltClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.bluetooth])
                    }
                    Toggle {
                        icon: Notifications.silent ? "notifications_paused" : "notifications_active"
                        label: "Silêncio"
                        status: Notifications.silent ? "ligado" : "desligado"
                        on: Notifications.silent
                        onClicked: Notifications.silent = !Notifications.silent
                    }
                    Toggle {
                        icon: "nightlight"
                        label: "Luz noturna"
                        status: Hyprsunset.temperatureActive ? "ligada" : "desligada"
                        on: Hyprsunset.temperatureActive
                        onClicked: Hyprsunset.toggleTemperature()
                    }
                    Toggle {
                        icon: "coffee"
                        label: "Café"
                        status: Idle.inhibit ? "tela acordada" : "desligado"
                        on: Idle.inhibit
                        onClicked: Idle.toggleInhibit()
                    }
                    Toggle {
                        readonly property bool muted: Audio.source?.audio?.muted ?? false
                        icon: muted ? "mic_off" : "mic"
                        label: "Microfone"
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
                            value: Audio.sink?.audio?.volume ?? 0
                            onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.volume = v; }
                            onIconClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                        }
                        Slide {
                            readonly property var monitor: Brightness.getMonitorForScreen(panel.screen)
                            icon: "light_mode"
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
                                font.pixelSize: 11
                                color: Appearance.colors.colOnLayer0
                                opacity: 0.7
                            }
                        }
                        IconKey {
                            enabled: phoneBox.charge >= 0
                            icon: "ring_volume"
                            tip: "Tocar o celular"
                            onClicked: Quickshell.execDetached(["qdbus", "org.kde.kdeconnect", root.phonePath + "/findmyphone", "org.kde.kdeconnect.device.findmyphone.ring"])
                        }
                        IconKey {
                            enabled: phoneBox.charge >= 0
                            icon: "notifications"
                            tip: "Ping"
                            onClicked: Quickshell.execDetached(["qdbus", "org.kde.kdeconnect", root.phonePath + "/ping", "org.kde.kdeconnect.device.ping.sendPing"])
                        }
                        IconKey {
                            enabled: phoneBox.charge >= 0
                            icon: "upload_file"
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
                    implicitHeight: 336
                    CalendarWidget {
                        anchors.fill: parent
                        anchors.margins: 8
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
                        font.pixelSize: 13
                        font.weight: MosaicTheme.brutal ? Font.Black : Font.DemiBold
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

    // A block of the column, in the theme's style
    component Section: Rectangle {
        radius: Appearance.rounding.normal
        color: MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1
        border.width: MosaicTheme.border
        border.color: MosaicTheme.ink
        HardShadow {}
    }

    // A quick toggle: icon, name and state; on = coloured. Right click: its settings
    component Toggle: Rectangle {
        id: tg
        required property string icon
        required property string label
        property string status: ""
        property bool on: false
        signal clicked()
        signal altClicked()
        Layout.fillWidth: true
        implicitHeight: 64
        radius: Appearance.rounding.normal
        color: on ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.32))
            : (MosaicTheme.brutal ? MosaicTheme.slabRaised : Appearance.colors.colLayer1)
        border.width: MosaicTheme.border
        border.color: MosaicTheme.ink
        Behavior on color { ColorAnimation { duration: 180 } }
        transform: Translate { x: tgShadow.sinkShift; y: tgShadow.sinkShift }
        HardShadow { id: tgShadow; sink: tgArea.pressed }
        scale: !MosaicTheme.brutal && tgArea.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        ColumnLayout {
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
        MouseArea {
            id: tgArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.RightButton ? tg.altClicked() : tg.clicked()
        }
    }

    // A slider: icon (click = its own action) and a track that fills on a spring
    component Slide: RowLayout {
        id: sl
        required property string icon
        property real value: 0
        signal moved(real v)
        signal iconClicked()
        spacing: 10
        IconKey {
            icon: sl.icon
            onClicked: sl.iconClicked()
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 28
            Rectangle {
                id: track
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
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            color: Appearance.colors.colOnLayer0
        }
    }

    // A small square key with an icon
    component IconKey: Rectangle {
        id: key
        required property string icon
        property string tip: ""
        signal clicked()
        implicitWidth: 36
        implicitHeight: 36
        radius: Appearance.rounding.small
        opacity: enabled ? 1 : 0.4
        color: keyArea.containsMouse ? (MosaicTheme.brutal ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.88))
            : (MosaicTheme.brutal ? MosaicTheme.slab : "transparent")
        border.width: MosaicTheme.brutal ? 1.5 : 0
        border.color: MosaicTheme.ink
        transform: Translate { x: keyShadow.sinkShift; y: keyShadow.sinkShift }
        HardShadow { id: keyShadow; size: 2; sink: keyArea.pressed }
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.icon
            iconSize: 20
            color: Appearance.colors.colOnLayer0
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
}
