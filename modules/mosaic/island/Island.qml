pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar

// Mosaic OS island: a notch on the top edge with the living Mosaic mark, dressed
// like the bottom bar (its surface and outline) with blocks in the Matugen tones
// inside, the way the bar groups its things.
// - Notifications show up whole inside it; the mark jumps.
// - Click anywhere opens the panel (stays until a click outside or Esc).
//   Pushing the mouse to the top edge opens it too, and then it closes when the
//   mouse leaves.
// - Panel: time + weather, music under them, quick tools (they left the bottom
//   bar) and the performance mosaic (CPU, RAM, GPU, swap filling up).
Scope {
    id: root

    // One panel at a time: the screen it is open on, and whether the mouse opened it
    property string openScreen: ""
    property bool openedByHover: false
    readonly property bool hasNotifs: Notifications.popupList.length > 0
    // a player with something loaded (browsers keep idle players around)
    readonly property bool hasPlayer: (MprisController.activePlayer?.trackTitle ?? "") !== ""
    readonly property bool playing: MprisController.isPlaying

    signal jumpRequested()

    // Soft colors: the Matugen tones mixed into the bar surface, so neighbors blend
    function softBlock(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.32); }
    function softTone(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.72); }

    Connections {
        target: Notifications
        function onNotify(notification) {
            if (!Notifications.silent)
                root.jumpRequested();
        }
    }

    // qs -c mosaic ipc call island <toggle|close|poke>
    IpcHandler {
        target: "island"
        function toggle(): void {
            const focused = Hyprland.focusedMonitor?.name ?? "";
            root.openedByHover = false;
            root.openScreen = root.openScreen === focused ? "" : focused;
        }
        function close(): void { root.openScreen = ""; }
        function poke(): void { root.jumpRequested(); }
        // shows the compass without holding Super (tests, or a keybind later)
        function compass(): void { root.compassForced = !root.compassForced; }
    }
    property bool compassForced: false

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:island"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            color: "transparent"
            implicitWidth: 560
            implicitHeight: 660
            // The notch, plus a thin strip on the top edge that opens it on hover
            mask: Region {
                item: notch
                Region {
                    item: edgeSensor
                }
            }

            // ---------- compass: Super held + mouse on the island ----------
            // Holding Super opens it: right away with the mouse on the island,
            // otherwise after a short hold of Super alone on the focused screen (so
            // shortcuts like Super+Q don't flash it). With the panel open, Super turns
            // the island into the compass too. Letting go brings back what was there.
            property bool compassOpen: false
            readonly property bool isFocusedScreen: Hyprland.focusedMonitor?.name === win.screen.name
            function updateCompass() {
                if (!GlobalStates.superDown)
                    win.compassOpen = false;
                else if (notchHover.hovered)
                    win.compassOpen = true;
            }
            Timer {
                id: superHold
                interval: 260
                // another key pressed with Super clears superReleaseMightTrigger: that's a shortcut
                onTriggered: if (GlobalStates.superDown && GlobalStates.superReleaseMightTrigger && win.isFocusedScreen) win.compassOpen = true
            }
            // While the compass is up, letting go of Super must not open the search
            onCompassOpenChanged: if (compassOpen) GlobalStates.superReleaseMightTrigger = false
            Connections {
                target: GlobalStates
                function onSuperDownChanged() {
                    win.updateCompass();
                    if (GlobalStates.superDown)
                        superHold.restart();
                }
            }

            readonly property bool panelOpen: root.openScreen === win.screen.name
            readonly property bool pinned: win.panelOpen && !root.openedByHover
            function setOpen(open, byHover) {
                root.openedByHover = open && (byHover ?? false);
                root.openScreen = open ? win.screen.name : (root.openScreen === win.screen.name ? "" : root.openScreen);
            }

            // Opened by click: keyboard (Esc) and click-outside close it, like the ii sidebars
            WlrLayershell.keyboardFocus: win.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            HyprlandFocusGrab {
                active: win.pinned && !ledPopup.open
                windows: [win]
                onCleared: win.setOpen(false)
            }

            // ---------- hover: the top edge opens it, leaving closes it ----------
            Item {
                id: edgeSensor
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360
                height: 2
                HoverHandler {
                    onHoveredChanged: if (hovered && !win.panelOpen && !root.hasNotifs && !GlobalStates.superDown) win.setOpen(true, true)
                }
            }
            Timer {
                id: leaveTimer
                interval: 350
                onTriggered: if (root.openedByHover && win.panelOpen && !notchHover.hovered && !ledPopup.open) win.setOpen(false)
            }

            Item {
                id: notch
                // what is open: notifications win over the panel
                readonly property bool compassOn: win.compassOpen || root.compassForced
                readonly property string mode: compassOn ? "compass" : root.hasNotifs ? "notifs" : win.panelOpen ? "panel" : ""
                // 0 = island, 1 = compass: drives the morph (shape, colors, needle)
                property real morph: compassOn ? 1 : 0
                Behavior on morph { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                readonly property real restWidth: 64
                readonly property real restHeight: 32
                readonly property real radius: Appearance.rounding.windowRounding

                anchors.horizontalCenter: parent.horizontalCenter
                width: mode === "" ? restWidth : mode === "compass" ? 380 : 460
                // as a compass it is a half oval, flatter than a half circle
                readonly property real compassHeight: 124
                height: mode === "" ? restHeight : mode === "compass" ? compassHeight : Math.min(Math.round(content.implicitHeight) + restHeight + 14, 640)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                focus: win.pinned
                Keys.onEscapePressed: win.setOpen(false)

                HoverHandler {
                    id: notchHover
                    onHoveredChanged: {
                        if (!hovered)
                            leaveTimer.restart();
                        win.updateCompass();
                    }
                }

                // The bottom bar's surface and outline. The top corners sit above the
                // screen edge, so only the bottom ones show.
                // Turning into the compass, the bottom corners round up until the
                // island is a half circle, and the surface takes a soft wash of the
                // four tones.
                // (a circle squashed from the top edge: a half oval)
                Rectangle {
                    id: surface
                    readonly property real m: Math.max(0, Math.min(1, notch.morph))
                    readonly property real cornerRadius: notch.radius + (notch.width / 2 - notch.radius) * m
                    readonly property real squash: 1 + (2 * notch.compassHeight / 380 - 1) * m
                    x: 0
                    y: -cornerRadius * squash
                    width: notch.width
                    height: notch.height / squash + cornerRadius
                    transform: Scale { yScale: surface.squash }
                    radius: cornerRadius
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer0, 0.32 * notch.morph) }
                        GradientStop { position: 0.5; color: ColorUtils.mix(Appearance.colors.colSecondary, Appearance.colors.colLayer0, 0.2 * notch.morph) }
                        GradientStop { position: 1.0; color: ColorUtils.mix(Appearance.colors.colTertiary, Appearance.colors.colLayer0, 0.32 * notch.morph) }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (notch.mode === "notifs")
                            GlobalStates.sidebarRightOpen = true;
                        else if (root.openedByHover && win.panelOpen)
                            root.openedByHover = false; // a click pins a panel the mouse opened
                        else
                            win.setOpen(!win.panelOpen);
                    }
                }

                Mascot {
                    id: mascot
                    // in the compass it grows into the needle and turns a quarter per workspace
                    size: 18 + 10 * notch.morph
                    showFace: false
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((notch.restHeight - 18) / 2 + 2 * notch.morph)
                    rotation: notch.mode === "compass" ? compassContent.offset * 90 : 0
                    Behavior on rotation { enabled: notch.mode !== "compass"; NumberAnimation { duration: 300 } }
                    baseMood: root.playing ? "dance" : "idle"
                    Connections {
                        target: root
                        function onJumpRequested() { mascot.jump(); }
                    }
                    // only a toy while the island is open; closed, a click opens it
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: notch.mode === "panel"
                        onClicked: mascot.poke()
                    }
                }

                Compass {
                    id: compassContent
                    anchors.fill: parent
                    open: notch.mode === "compass" && notch.morph > 0.6
                    visible: notch.mode === "compass" || reveal > 0
                }

                Item {
                    id: content
                    readonly property real implicitHeight: loader.item ? loader.item.implicitHeight : 0
                    x: 12
                    y: notch.restHeight + 2
                    width: notch.width - 24
                    height: notch.height - notch.restHeight - 8
                    clip: true
                    opacity: (notch.mode === "panel" || notch.mode === "notifs") ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Loader {
                        id: loader
                        width: parent.width
                        active: notch.mode === "panel" || notch.mode === "notifs"
                        sourceComponent: notch.mode === "notifs" ? notifsView : panelView
                    }
                }
            }

            // ---------- notifications, whole ----------
            Component {
                id: notifsView
                NotificationListView {
                    implicitHeight: contentHeight
                    height: contentHeight
                    popup: true
                    expandAll: true
                }
            }

            // ---------- panel ----------
            Component {
                id: panelView
                ColumnLayout {
                    spacing: 6

                    // time (primary block) + weather (tertiary block)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Block {
                            Layout.fillWidth: true
                            tint: root.softBlock(Appearance.colors.colPrimary)
                            tint2: root.softBlock(Appearance.colors.colSecondary)
                            implicitHeight: 64
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10
                                StyledText {
                                    text: DateTime.time
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 34
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 13
                                    text: DateTime.longDate
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 13
                                    color: Appearance.colors.colOnLayer0
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        Block {
                            tint: root.softBlock(Appearance.colors.colSecondary)
                            tint2: root.softBlock(Appearance.colors.colTertiary)
                            implicitWidth: 124
                            implicitHeight: 64
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                                    iconSize: 28
                                    color: Appearance.colors.colOnLayer0
                                }
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: Weather.data?.temp ?? "--°"
                                        font.family: "Space Grotesk"
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnLayer0
                                    }
                                    StyledText {
                                        visible: (Weather.data?.city ?? "") !== ""
                                        Layout.maximumWidth: 70
                                        text: Weather.data?.city ?? ""
                                        font.pixelSize: 10
                                        color: Appearance.colors.colOnLayer0
                                        opacity: 0.75
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // music, under time and weather (secondary block)
                    Block {
                        visible: root.hasPlayer
                        Layout.fillWidth: true
                        tint: root.softBlock(Appearance.colors.colTertiary)
                        tint2: root.softBlock(Appearance.colors.colPrimary)
                        implicitHeight: 60
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            ClippingRectangle {
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer1
                                Image {
                                    anchors.fill: parent
                                    source: MprisController.activePlayer?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(88, 88)
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                StyledText {
                                    Layout.fillWidth: true
                                    text: MprisController.activePlayer?.trackTitle ?? ""
                                    font.family: "Space Grotesk"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: MprisController.activePlayer?.trackArtist ?? ""
                                    font.pixelSize: 11
                                    color: Appearance.colors.colOnLayer0
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                }
                            }
                            Repeater {
                                model: [
                                    { icon: "skip_previous", act: () => MprisController.previous() },
                                    { icon: root.playing ? "pause" : "play_arrow", act: () => MprisController.togglePlaying() },
                                    { icon: "skip_next", act: () => MprisController.next() }
                                ]
                                delegate: RippleButton {
                                    required property var modelData
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    padding: 0
                                    buttonRadius: 17
                                    onClicked: modelData.act()
                                    contentItem: Item {
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            iconSize: 22
                                            fill: 1
                                            color: Appearance.colors.colOnLayer0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // quick tools (bar-group block) + performance mosaic
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Block {
                            Layout.fillWidth: true
                            tint: Appearance.colors.colLayer1
                            implicitHeight: 80
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 0
                                QuickTool {
                                    icon: "screenshot_region"
                                    label: "Print"
                                    onClicked: {
                                        win.setOpen(false);
                                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                                    }
                                }
                                QuickTool {
                                    icon: "colorize"
                                    label: "Cor"
                                    onClicked: {
                                        win.setOpen(false);
                                        Quickshell.execDetached(["bash", "-c", "sleep 0.3; hyprpicker -a"]);
                                    }
                                }
                                QuickTool {
                                    icon: Notifications.silent ? "notifications_paused" : "notifications_active"
                                    label: "Silêncio"
                                    toggled: Notifications.silent
                                    onClicked: Notifications.silent = !Notifications.silent
                                }
                                QuickTool {
                                    id: ledTool
                                    icon: "light_mode"
                                    label: "LED"
                                    onClicked: {
                                        ledPopup.anchorItem = ledTool;
                                        ledPopup.open = !ledPopup.open;
                                    }
                                }
                                QuickTool {
                                    visible: Battery.available
                                    icon: Battery.isCharging ? "battery_charging_full" : "smartphone"
                                    label: `${Math.round(Battery.percentage * 100)}%`
                                }
                            }
                        }
                        // the four Mosaic blocks fill up from the bottom
                        Block {
                            tint: Appearance.colors.colLayer1
                            implicitWidth: 80
                            implicitHeight: 80
                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 4
                                FillTile { value: ResourceUsage.cpuUsage; icon: "memory"; tone: root.softTone(Appearance.colors.colPrimary) }
                                FillTile { value: ResourceUsage.memoryUsedPercentage; icon: "memory_alt"; tone: root.softTone(Appearance.colors.colSecondary) }
                                FillTile { value: gpuBusy.value; icon: "developer_board"; tone: root.softTone(Appearance.colors.colTertiary) }
                                FillTile { value: ResourceUsage.swapUsedPercentage; icon: "swap_horiz"; tone: root.softTone(Appearance.colors.colOnLayer0) }
                            }
                        }
                    }
                }
            }

            // GPU load (amdgpu), read only while the panel is open
            QtObject {
                id: gpuBusy
                property real value: 0
            }
            FileView {
                id: gpuFile
                path: "/sys/class/drm/card1/device/gpu_busy_percent"
                onLoaded: gpuBusy.value = (parseInt(text()) || 0) / 100
            }
            Timer {
                running: win.panelOpen
                repeat: true
                triggeredOnStart: true
                interval: 2000
                onTriggered: gpuFile.reload()
            }

            Bar.LedPopup {
                id: ledPopup
                atTop: true
                edgeMargin: notch.height + 6
            }
        }
    }

    // A block inside the island, like a bar group, in one Matugen tone
    component Block: Rectangle {
        id: block
        property color tint: Appearance.colors.colLayer1
        property color tint2: tint // the tone it flows into, left to right
        radius: Appearance.rounding.small
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: block.tint }
            GradientStop { position: 1; color: block.tint2 }
        }
    }

    // A round quick tool with a caption under it: fixed cell, icon truly centered
    component QuickTool: Item {
        id: tool
        required property string icon
        required property string label
        property bool toggled: false
        signal clicked()
        Layout.fillWidth: true
        implicitWidth: 52
        implicitHeight: 66
        RippleButton {
            id: toolButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 42
            height: 42
            padding: 0
            buttonRadius: 21
            toggled: tool.toggled
            colBackground: Appearance.colors.colLayer2
            onClicked: tool.clicked()
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: tool.icon
                    iconSize: 20
                    color: tool.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: toolButton.bottom
            anchors.topMargin: 4
            text: tool.label
            font.family: "Space Grotesk"
            font.pixelSize: 11
            color: Appearance.colors.colSubtext
        }
    }

    // One performance reading as a little glass filling with water: just the
    // icon and the water level. The level moves on a soft spring and the surface
    // sloshes a bit (only while the panel is open, so it costs nothing closed).
    component FillTile: Item {
        id: tile
        required property real value
        required property string icon
        required property color tone
        readonly property real level: Math.max(0.04, Math.min(1, value))
        property real shownLevel: level
        Behavior on shownLevel { SpringAnimation { spring: 2.2; damping: 0.12; epsilon: 0.002 } }
        property real phase: 0
        width: 32
        height: 32

        FrameAnimation {
            running: tile.visible
            onTriggered: {
                tile.phase += frameTime * 3.2;
                water.requestPaint();
            }
        }

        // the glass
        Rectangle {
            id: glass
            anchors.fill: parent
            radius: 8
            color: ColorUtils.transparentize(tile.tone, 0.85)
            border.width: 1
            border.color: ColorUtils.transparentize(tile.tone, 0.6)
        }
        // the water, clipped to the glass shape
        Canvas {
            id: water
            anchors.fill: parent
            anchors.margins: 1
            property color fill: tile.tone
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height, r = 7;
                // glass shape as the clip
                ctx.beginPath();
                ctx.roundedRect(0, 0, w, h, r, r);
                ctx.clip();
                const top = h * (1 - tile.shownLevel);
                const amp = 1.6 + Math.abs(tile.level - tile.shownLevel) * 10; // sloshes more while moving
                ctx.beginPath();
                ctx.moveTo(0, h);
                for (let x = 0; x <= w; x += 2)
                    ctx.lineTo(x, top + Math.sin(tile.phase + x / w * Math.PI * 2) * amp);
                ctx.lineTo(w, h);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(fill.r, fill.g, fill.b, 0.85);
                ctx.fill();
                // a lighter wave behind, for depth
                ctx.beginPath();
                ctx.moveTo(0, h);
                for (let x = 0; x <= w; x += 2)
                    ctx.lineTo(x, top - 1 + Math.sin(tile.phase * 0.8 + 1.7 + x / w * Math.PI * 2) * amp * 0.8);
                ctx.lineTo(w, h);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(fill.r, fill.g, fill.b, 0.35);
                ctx.fill();
            }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: tile.icon
            iconSize: 17
            fill: 1
            color: Appearance.colors.colOnLayer0
            opacity: 0.9
        }
    }
}
