pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
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
    // brutal themes (Gruvbox): stronger, flat colours instead of the soft blend
    function softBlock(c) { return MosaicTheme.brutal ? ColorUtils.mix(c, MosaicTheme.slab, 0.5) : ColorUtils.mix(c, Appearance.colors.colLayer1, 0.32); }
    function softTone(c) { return ColorUtils.mix(c, Appearance.colors.colLayer1, 0.72); }
    // The island's soft Mosaic wash: left, middle and right colours of its gradient.
    // Resting it is a light touch of the tones; as a compass (morph 1) a stronger one.
    function washStop(i, morph) {
        const c = Appearance.colors;
        const tone = [c.colPrimary, c.colSecondary, c.colTertiary][i];
        const amount = MosaicTheme.brutal ? 0 : (0.10 + 0.06 * morph) * (i === 1 ? 0.62 : 1); // the compass only a touch more coloured; brutal: flat
        return ColorUtils.mix(tone, root.islandBase, amount);
    }
    // the island is dark, like the hyprdots one: the bar surface pushed 55% toward black
    // (brutal themes keep the theme's own background, solid)
    // the Ilha tab sets how dark (darkness) and how solid (opacity) it is
    readonly property color islandBase: MosaicTheme.brutal ? MosaicTheme.slab : ColorUtils.mix("#000000", Appearance.colors.colLayer0, Config.options.mosaicIsland.darkness)
    readonly property real islandAlpha: MosaicTheme.brutal ? 1 : Config.options.mosaicIsland.opacity
    Component.onCompleted: MosaicGlass.load()
    // the outline: a hairline, or the thick cream line of brutal themes
    readonly property color outlineColor: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colLayer0Border
    // shaders mix colours themselves, so they get them opaque and the alpha apart
    function opaque(c) { return Qt.rgba(c.r, c.g, c.b, 1); }

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
        // open the start menu with something typed (tests, or a keybind later)
        function notes(): void { root.toggleNotes(); }
        function menuSearch(text: string): void {
            LauncherSearch.query = text;
            GlobalStates.searchOpen = true;
        }
        // pretend a phone event, to see the animations without the phone:
        // charging | low | ringing | talking | missed | connected | disconnected
        function phoneTest(kind: string): void {
            if (kind === "charging") {
                if (phone.charge < 0)
                    phone.charge = 64; // phone away: an example number
                phone.chargingStarted();
            }
            else if (kind === "low") root.showEvent("battery", "battery_alert", `${phone.name} com 15%`, 0.15);
            else if (kind === "ringing") phone.call("ringing", "+55 11 91234-5678", "Maria");
            else if (kind === "talking") phone.call("talking", "+55 11 91234-5678", "Maria");
            else if (kind === "missed") phone.call("missedCall", "+55 11 91234-5678", "Maria");
            else if (kind === "connected") phone.connected();
            else if (kind === "disconnected") phone.disconnected();
        }
    }
    property bool compassForced: false

    // ---------- start menu (Super tapped): GlobalStates.searchOpen ----------
    // The ii search shortcuts (Super, Super+V clipboard, Super+. emojis) now open
    // this menu instead of the ii overview (modules/ii/overview/Overview.qml).
    property string menuScreen: ""
    Connections {
        target: GlobalStates
        function onSearchOpenChanged() {
            if (GlobalStates.searchOpen) {
                root.notesOpen = false;
                root.menuScreen = Hyprland.focusedMonitor?.name ?? "";
                root.openScreen = ""; // the panel gives way
            } else {
                LauncherSearch.query = "";
            }
        }
    }
    RecentApps { id: recentApps }

    // ---------- notes (tools button or Super+Alt+N) ----------
    // the same card as the menu, with the notes inside (Notes.qml)
    property bool notesOpen: false
    property string notesScreen: ""
    function toggleNotes() {
        if (root.notesOpen) {
            root.notesOpen = false;
            return;
        }
        root.notesScreen = Hyprland.focusedMonitor?.name ?? "";
        root.openScreen = "";
        GlobalStates.searchOpen = false;
        root.notesOpen = true;
    }
    GlobalShortcut {
        name: "mosaicNotesToggle"
        description: "Abre e fecha as notas da ilha"
        onPressed: root.toggleNotes()
    }

    // ---------- events: quick things the island shows for a moment ----------
    // kind: "volume" | "brightness" | "music" | "print" | "battery" ("" = none)
    property string eventKind: ""
    property string eventIcon: ""
    property string eventText: ""
    property string eventSub: "" // a second line (the number of a call...)
    property real eventValue: 0
    property int eventSerial: 0 // goes up on every event, so the island can do its little bump
    function showEvent(kind, icon, text, value, sub) {
        root.eventKind = kind;
        root.eventIcon = icon;
        root.eventText = text;
        root.eventSub = sub ?? "";
        root.eventValue = value ?? 0;
        root.eventSerial++;
        // how long each kind stays: a ringing call stays until it is answered or missed
        eventTimer.interval = ({ music: 3200, charging: 3600, call: 45000, callTalking: 5000, callMissed: 6000, phone: 2600 })[kind] ?? 1800;
        eventTimer.restart();
    }
    Timer {
        id: eventTimer
        onTriggered: root.eventKind = ""
    }
    // nothing fires during the first seconds (players and services settling in)
    property bool eventsReady: false
    Timer {
        running: true
        interval: 3000
        onTriggered: root.eventsReady = true
    }

    // volume and brightness: the island takes the place of the ii OSD
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { root.volumeEvent(); }
        function onMutedChanged() { root.volumeEvent(); }
    }
    function volumeEvent() {
        if (!Audio.ready || !root.eventsReady)
            return;
        const muted = Audio.sink?.audio?.muted ?? false;
        const v = Audio.sink?.audio?.volume ?? 0;
        root.showEvent("volume", muted ? "volume_off" : v < 0.01 ? "volume_mute" : v < 0.5 ? "volume_down" : "volume_up", "", muted ? 0 : v);
    }
    Connections {
        target: Brightness
        function onBrightnessChanged() {
            if (!root.eventsReady)
                return;
            const screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
            const v = screen ? (Brightness.getMonitorForScreen(screen)?.brightness ?? 0) : 0;
            root.showEvent("brightness", "light_mode", "", v);
        }
    }
    // a new song started
    property string lastTrack: ""
    readonly property string currentTrack: MprisController.activePlayer?.trackTitle ?? ""
    onCurrentTrackChanged: {
        if (root.currentTrack !== "" && root.currentTrack !== root.lastTrack && root.eventsReady && root.playing)
            root.showEvent("music", "music_note", root.currentTrack, 0);
        root.lastTrack = root.currentTrack;
    }
    // an image landed on the clipboard (every print here goes through wl-copy):
    // wl-paste --watch runs the check only when the clipboard changes, so idle it costs nothing
    Process {
        running: true
        // setpriv --pdeathsig: it dies together with the shell (otherwise every restart left one behind)
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--watch", "sh", "-c", "wl-paste -l | grep -q '^image/' && echo image"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "image" && root.eventsReady)
                    root.showEvent("print", "screenshot_monitor", "Print copiado", 0);
            }
        }
    }
    // ---------- screen recording (the ii's record.sh, i.e. wf-recorder) ----------
    // Recording is "wf-recorder is running", however it was started (the tools
    // button, the ii keybinds...). Checked every 1.5 s with pgrep, which is cheap.
    property bool recording: false
    property real recordStart: 0
    property int recordSeconds: 0
    readonly property string recordScript: Quickshell.shellPath("scripts/videos/record.sh")
    // pgrep finds it; ps tells how long it has been running (etimes, in seconds),
    // so the clock is right even when the recording started before we noticed
    Process {
        id: recCheck
        command: ["sh", "-c", "pid=$(pgrep -x wf-recorder | head -1) && ps -o etimes= -p \"$pid\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const secs = parseInt(this.text);
                const now = !isNaN(secs);
                if (now && !root.recording)
                    root.recordStart = Date.now() - secs * 1000;
                root.recording = now;
            }
        }
    }
    Timer {
        running: true
        repeat: true
        interval: 1500
        onTriggered: recCheck.running = true
    }
    Timer { // the elapsed time, only while recording
        running: root.recording
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: root.recordSeconds = Math.floor((Date.now() - root.recordStart) / 1000)
    }
    // the whole screen (the focused monitor) with sound; while recording, stops it
    function toggleRecording() {
        if (root.recording)
            Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
        else
            Quickshell.execDetached(["bash", "-c", `sleep 0.3; '${root.recordScript}' --sound --fullscreen`]);
        recheckSoon.restart(); // show the change right away, not at the next 1.5 s check
    }
    Timer {
        id: recheckSoon
        interval: 700
        onTriggered: recCheck.running = true
    }

    // ---------- the phone, through KDE Connect (PhoneLink.qml) ----------
    PhoneLink { id: phone }
    Connections {
        target: phone
        function onChargingStarted() { root.showEvent("charging", "bolt", "Carregando", phone.charge / 100, phone.name); }
        function onConnected() { root.showEvent("phone", "smartphone", `${phone.name} conectado`, 0); }
        function onDisconnected() { root.showEvent("phone", "mobile_off", `${phone.name} desconectado`, 0); }
        function onCall(event, number, contactName) {
            const who = contactName !== "" ? contactName : number;
            if (event === "ringing")
                root.showEvent("call", "call", who, 0, number !== who ? number : phone.name);
            else if (event === "talking")
                root.showEvent("callTalking", "call", who, 0, "Em ligação");
            else if (event === "missedCall")
                root.showEvent("callMissed", "phone_missed", who, 0, "Ligação perdida");
        }
    }
    // going low (20%, off the charger)
    readonly property bool phoneLow: phone.charge > 0 && phone.charge <= 20 && !phone.charging
    onPhoneLowChanged: if (root.phoneLow) root.showEvent("battery", "battery_alert", `${phone.name} com ${phone.charge}%`, phone.charge / 100)

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:island"
            WlrLayershell.layer: WlrLayer.Overlay // above full-screen windows, so the top edge still works
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            color: "transparent"
            implicitWidth: 680 // room for the start menu card (640)
            implicitHeight: 660
            // The notch, plus a thin strip on the top edge that opens it on hover
            mask: Region {
                item: notch
                Region {
                    item: edgeSensor
                }
                Region {
                    item: bubbleClip
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
                interval: 130
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
            property bool trayBusy: false // a tray menu is open (set by the tray in the panel)
            function setOpen(open, byHover) {
                root.openedByHover = open && (byHover ?? false);
                root.openScreen = open ? win.screen.name : (root.openScreen === win.screen.name ? "" : root.openScreen);
            }

            // Opened by click: keyboard (Esc) and click-outside close it, like the ii sidebars
            readonly property bool menuHere: GlobalStates.searchOpen && root.menuScreen === win.screen.name
            readonly property bool notesHere: root.notesOpen && root.notesScreen === win.screen.name
            readonly property bool cardHere: win.menuHere || win.notesHere // the menu or the notes: they take the keyboard
            // click-outside for the menu starts a moment after it opens: switched on at
            // once, it fired before the menu card existed and closed it right away
            property bool menuGrab: false
            onCardHereChanged: {
                win.menuGrab = false;
                if (win.cardHere)
                    menuGrabDelay.restart();
            }
            Timer {
                id: menuGrabDelay
                interval: 300
                onTriggered: win.menuGrab = win.cardHere
            }
            WlrLayershell.keyboardFocus: win.cardHere ? WlrKeyboardFocus.Exclusive : win.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            HyprlandFocusGrab {
                active: (win.pinned && !ledPopup.open && !win.trayBusy) || win.menuGrab
                windows: [win]
                onCleared: {
                    win.setOpen(false);
                    if (win.menuHere)
                        GlobalStates.searchOpen = false;
                    if (win.notesHere)
                        root.notesOpen = false;
                }
            }

            // ---------- hover: the top edge opens it, leaving closes it ----------
            Item {
                id: edgeSensor
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360
                height: 2
                HoverHandler {
                    onHoveredChanged: if (hovered && !win.panelOpen && !GlobalStates.superDown) win.setOpen(true, true)
                }
            }
            Timer {
                id: leaveTimer
                interval: 350
                onTriggered: if (root.openedByHover && win.panelOpen && !notchHover.hovered && !ledPopup.open && !win.trayBusy) win.setOpen(false)
            }

            Item {
                id: notch
                // what the island is showing, by priority
                readonly property bool compassOn: win.compassOpen || root.compassForced
                readonly property bool showEvent: root.eventKind !== "" && win.isFocusedScreen
                readonly property string mode: compassOn ? "compass" : win.panelOpen ? "panel" : showEvent ? "event" : ""
                readonly property real restHeight: 30
                // floating like a pill: fully round while small, a 26 px curve when it grows
                readonly property real cornerRadius: MosaicTheme.r(Math.min(height / 2, 26)) // a pill in Mosaic, a box in Gruvbox
                readonly property real topGap: 6 // the space above it, under the screen edge
                readonly property real compassHeight: 112 // as a compass it is a small dome (half oval), with the mark on top
                readonly property real bandHeight: mode !== "event" ? restHeight
                    : root.eventKind.startsWith("call") ? 58
                    : root.eventKind === "music" || root.eventKind === "charging" || root.eventKind === "battery" ? 48 : 38

                // ----- the springs (MosaicSpring: real physics, with speed) -----
                readonly property real targetWidth: mode === "" ? restRow.fullWidth + 24
                    : mode === "event" ? Math.max(restRow.fullWidth + 24, eventLoader.implicitWidth + 64)
                    : mode === "compass" ? 340 : 460
                readonly property real targetHeight: mode === "" || mode === "event" ? bandHeight
                    : mode === "compass" ? compassHeight
                    : Math.min(Math.round(content.implicitHeight) + restHeight + 14, 640)
                MosaicSpring { id: widthSpring; response: 0.42; damping: 0.72; epsilon: 0.2; target: notch.targetWidth; Component.onCompleted: settle(target) }
                MosaicSpring { id: heightSpring; response: 0.46; damping: 0.76; epsilon: 0.2; target: notch.targetHeight; Component.onCompleted: settle(target) }
                // 0 = island, 1 = compass: drives the shape, the colours and the needle
                MosaicSpring { id: morphSpring; response: 0.5; damping: 0.78; target: notch.compassOn ? 1 : 0 }
                // 0 = mark on the left (resting), 1 = mark in the middle (panel, compass)
                MosaicSpring { id: centerSpring; response: 0.4; damping: 0.8; target: notch.mode === "" || notch.mode === "event" ? 0 : 1 }
                // feel: grows a hair under the mouse, sinks when pressed, bumps on events
                MosaicSpring { id: hoverSpring; response: 0.38; damping: 0.92; target: notchHover.hovered ? 1 : 0 }
                MosaicSpring { id: pressSpring; response: 0.22; damping: 0.7; target: clickArea.pressed ? 1 : 0 }
                MosaicSpring { id: peekSpring; response: 0.3; damping: 0.7; target: 0 }
                Timer { id: peekHold; interval: 90; onTriggered: peekSpring.target = 0 }
                Connections {
                    target: root
                    function onEventSerialChanged() {
                        if (notch.showEvent) {
                            peekSpring.target = 1;
                            peekHold.restart();
                        }
                    }
                }

                readonly property real morph: morphSpring.value
                width: widthSpring.value
                height: heightSpring.value

                // jelly: the faster the island is changing size, the more it stretches
                // sideways and flattens (and the other way round when it slows down)
                readonly property real rush: widthSpring.velocity / 420 + heightSpring.velocity / 420 + morphSpring.velocity * 0.16
                readonly property real jelly: Math.max(-0.07, Math.min(0.07, rush * 0.052))
                readonly property real feel: (1 + 0.028 * hoverSpring.value) * (1 + 0.04 * peekSpring.value) * (1 - 0.035 * pressSpring.value)
                readonly property real scaleX: (1 + jelly) * feel
                readonly property real scaleY: (1 - jelly * 0.62) * feel

                // full screen on this monitor: the resting island hides above the edge
                // (the top edge sensor still opens the panel)
                readonly property int workspaceId: Hyprland.monitorFor(win.screen)?.activeWorkspace?.id ?? -1
                // Hyprland's fullscreen: 0 normal, 1 maximized, 2 real full screen. Only 2 hides it
                readonly property bool fullscreenHere: HyprlandData.windowList.some(w => w.workspace.id === notch.workspaceId && w.fullscreen >= 2)
                property real hideY: fullscreenHere && mode === "" ? -height - topGap - 6 : 0
                Behavior on hideY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                transform: [
                    Scale { origin.x: notch.width / 2; origin.y: notch.height / 2; xScale: notch.scaleX; yScale: notch.scaleY },
                    Translate { y: notch.hideY }
                ]

                anchors.horizontalCenter: parent.horizontalCenter
                y: topGap
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

                // The surface, drawn by shaders/island.frag: a dark pill floating
                // under the top edge (like the hyprdots island), with a light wash of
                // the Matugen tones. As the panel it is a rounded card; turning into
                // the compass, the bottom becomes a half circle squashed into a half
                // oval while the top keeps its small curve.
                // While the notification bubble is out, the goo layer draws the
                // island instead (same colours), so the two melt into one shape.
                ShaderEffect {
                    id: surface
                    readonly property real m: Math.max(0, Math.min(1, notch.morph))
                    // bigger than the island by the hard shadow (brutal themes)
                    width: notch.width + MosaicTheme.shadow
                    height: notch.height + MosaicTheme.shadow
                    opacity: bubble.living ? 0 : 1
                    fragmentShader: Qt.resolvedUrl("shaders/island.frag.qsb")
                    property vector2d size: Qt.vector2d(width, height)
                    property vector2d shapeSize: Qt.vector2d(notch.width, notch.height)
                    property real rTop: notch.cornerRadius
                    property real rBot: notch.cornerRadius + (notch.width / 2 - notch.cornerRadius) * m * Math.pow(MosaicTheme.roundness, 2) // boxy themes: (almost) no dome
                    // built taller than drawn while it is a compass: that is the squash
                    property real hu: notch.height + (notch.width / 2 + notch.cornerRadius - notch.height) * m * Math.pow(MosaicTheme.roundness, 2)
                    property color stop0: root.opaque(root.washStop(0, notch.morph))
                    property color stop1: root.opaque(root.washStop(1, notch.morph))
                    property color stop2: root.opaque(root.washStop(2, notch.morph))
                    property real fillAlpha: root.islandAlpha
                    property color strokeColor: root.opaque(root.outlineColor)
                    property real strokeAlpha: root.outlineColor.a
                    property real strokeWidth: MosaicTheme.brutal ? MosaicTheme.border : 1
                    property vector2d shadowOffset: Qt.vector2d(MosaicTheme.shadow, MosaicTheme.shadow)
                    property color shadowColor: root.opaque(MosaicTheme.shadowColor)
                    property real shadowAlpha: MosaicTheme.brutal ? 1 : 0
                    property real grain: MosaicTheme.grainIsland
                }

                MouseArea {
                    id: clickArea
                    anchors.fill: parent
                    onClicked: {
                        if (root.openedByHover && win.panelOpen)
                            root.openedByHover = false; // a click pins a panel the mouse opened
                        else
                            win.setOpen(!win.panelOpen);
                    }
                }

                Mascot {
                    id: mascot
                    // resting: on the left of the row; panel: on top in the middle;
                    // compass: it grows into the needle and turns a quarter per workspace
                    readonly property real c: centerSpring.value
                    size: 16 + 4 * notch.morph
                    showFace: false
                    x: 12 + ((notch.width - width) / 2 - 12) * c
                    y: Math.round((Math.min(notch.height, notch.bandHeight) - size) / 2 * (1 - c) + ((notch.restHeight - 18) / 2 + 1 * notch.morph) * c)
                    rotation: notch.mode === "compass" ? compassContent.offset * 90 : 0
                    Behavior on rotation { enabled: notch.mode !== "compass"; NumberAnimation { duration: 300 } }
                    baseMood: root.playing ? "dance" : "idle"
                    // resting with music on: the album cover sits where the mark is
                    opacity: notch.showCover ? 0 : 1
                    scale: notch.showCover ? 0.6 : 1
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
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

                // the album cover, in the mark's place while music plays (resting only)
                readonly property bool showCover: mode === "" && root.playing && (MprisController.activePlayer?.trackArtUrl ?? "") !== ""
                ClippingRectangle {
                    x: mascot.x - 1
                    y: mascot.y - 1
                    width: 18
                    height: 18
                    radius: MosaicTheme.r(5)
                    color: Appearance.colors.colLayer1
                    opacity: notch.showCover ? 1 : 0
                    scale: notch.showCover ? 1 : 0.5
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    border.width: MosaicTheme.brutal ? 1.5 : 0
                    border.color: MosaicTheme.ink
                    Image {
                        anchors.fill: parent
                        source: MprisController.activePlayer?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(36, 36)
                        asynchronous: true
                    }
                }

                // ----- resting row: mark · time · weather -----
                Row {
                    id: restRow
                    // fullWidth includes the mark's room, so the island sizes around all three
                    readonly property real lead: 16 + 10
                    x: 12 + lead
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: Math.min(notch.height, notch.restHeight) / 2
                    spacing: 10
                    opacity: notch.mode === "" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    readonly property real fullWidth: lead + timeText.implicitWidth + spacing + rightSlot.implicitWidth
                    StyledText {
                        id: timeText
                        anchors.verticalCenter: parent.verticalCenter
                        text: DateTime.time
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer0
                    }
                    // the right slot: recording, else music playing, else the weather
                    Loader {
                        id: rightSlot
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: root.recording ? recSlot : root.playing ? playingSlot : weatherSlot
                    }
                }

                Component {
                    id: weatherSlot
                    Row {
                        id: weatherRow
                        spacing: 3
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.data?.temp ?? "--"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.85
                        }
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            iconSize: 16
                            fill: 1
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }
                // recording: a red dot that breathes and the time running
                Component {
                    id: recSlot
                    Row {
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: MosaicTheme.r(4.5)
                            color: Appearance.colors.colError
                            SequentialAnimation on opacity {
                                running: true
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const t = root.recordSeconds;
                                return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
                            }
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Appearance.colors.colError
                        }
                    }
                }
                // music playing: four little bars bouncing, each at its own pace
                Component {
                    id: playingSlot
                    Row {
                        spacing: 2
                        height: 14
                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                id: bar
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 3
                                radius: MosaicTheme.r(1.5)
                                color: Appearance.colors.colPrimary
                                height: 4
                                SequentialAnimation on height {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 6 + (bar.index * 5 % 8); duration: 260 + bar.index * 70; easing.type: Easing.OutQuad }
                                    NumberAnimation { to: 13 - bar.index * 2; duration: 220 + bar.index * 50; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 3; duration: 300 + bar.index * 40; easing.type: Easing.InQuad }
                                }
                            }
                        }
                    }
                }

                // ----- event row: what just happened, next to the mark -----
                Loader {
                    id: eventLoader
                    x: 12 + 16 + 12
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: Math.min(notch.height, notch.bandHeight) / 2
                    active: notch.showEvent
                    opacity: notch.mode === "event" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    sourceComponent: root.eventKind === "volume" || root.eventKind === "brightness" ? levelEvent
                        : root.eventKind === "music" ? musicEvent
                        : root.eventKind === "charging" || root.eventKind === "battery" ? batteryEvent
                        : root.eventKind.startsWith("call") ? callEvent
                        : root.eventKind === "phone" ? phoneEvent : textEvent
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
                    width: notch.width - 24 // (the blocks leave room for their hard shadow in brutal themes)
                    height: notch.height - notch.restHeight - 8
                    clip: true
                    opacity: notch.mode === "panel" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Loader {
                        id: loader
                        width: parent.width
                        active: notch.mode === "panel"
                        sourceComponent: panelView
                    }
                }
            }

            // ---------- event contents ----------
            Component {
                id: levelEvent
                Row {
                    spacing: 10
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.eventIcon
                        iconSize: 18
                        fill: 1
                        color: Appearance.colors.colOnLayer0
                    }
                    // the bar fills on a spring, so holding the key feels liquid
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 140
                        height: 6
                        radius: MosaicTheme.r(3)
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
                        Rectangle {
                            height: parent.height
                            radius: MosaicTheme.r(3)
                            width: parent.width * levelSpring.value
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Appearance.colors.colPrimary }
                                GradientStop { position: 1; color: Appearance.colors.colTertiary }
                            }
                        }
                        MosaicSpring { id: levelSpring; response: 0.3; damping: 0.8; epsilon: 0.002; target: Math.max(0, Math.min(1, root.eventValue)) }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        text: Math.round(root.eventValue * 100)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        color: Appearance.colors.colOnLayer0
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
            Component {
                id: musicEvent
                Row {
                    spacing: 10
                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: MosaicTheme.r(8)
                        color: Appearance.colors.colLayer1
                        Image {
                            anchors.fill: parent
                            source: MprisController.activePlayer?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(68, 68)
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(220, Math.max(titleText.implicitWidth, artistText.implicitWidth))
                        StyledText {
                            id: titleText
                            width: parent.width
                            text: MprisController.activePlayer?.trackTitle ?? ""
                            font.family: MosaicTheme.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                        StyledText {
                            id: artistText
                            width: parent.width
                            text: MprisController.activePlayer?.trackArtist ?? ""
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.75
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            // charging started / phone going low: the water battery, the percentage counting up, sparks
            Component {
                id: batteryEvent
                Row {
                    spacing: 14
                    Item {
                        width: 60
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        PhoneBattery {
                            anchors.fill: parent
                            value: root.eventValue
                            charging: root.eventKind === "charging"
                            tint: ColorUtils.mix("#1ed38a", Appearance.colors.colPrimary, 0.55) // the Mosaic green, tuned to the wallpaper
                        }
                        Sparks {
                            visible: root.eventKind === "charging"
                            x: 28
                            y: 14
                            tint: "#1ed38a"
                            reach: 42
                            delay: 380
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText {
                            text: root.eventText
                            font.family: MosaicTheme.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: root.eventSub !== "" ? root.eventSub : phone.name
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.7
                        }
                    }
                    // the percentage counts up to the real number
                    StyledText {
                        id: pct
                        anchors.verticalCenter: parent.verticalCenter
                        property real counted: 0
                        Component.onCompleted: counted = root.eventValue * 100
                        Behavior on counted { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
                        text: Math.round(counted) + "%"
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }
            // a call: the contact's initial in a pulsing circle with rings going out
            // (ringing), the name and number, and a button to silence the phone
            Component {
                id: callEvent
                Row {
                    id: callRow
                    spacing: 14
                    readonly property bool ringing: root.eventKind === "call"
                    readonly property color tone: root.eventKind === "callMissed" ? Appearance.colors.colError : ColorUtils.mix("#1ed38a", Appearance.colors.colPrimary, 0.55)
                    Item {
                        width: 40
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater { // two rings, half a beat apart
                            model: callRow.ringing ? 2 : 0
                            delegate: Rectangle {
                                id: ring
                                required property int index
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                radius: MosaicTheme.r(20)
                                color: "transparent"
                                border.width: 2
                                border.color: callRow.tone
                                opacity: 0
                                SequentialAnimation {
                                    running: true
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: ring.index * 600 }
                                    ParallelAnimation {
                                        NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.7; duration: 1800; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 1800; easing.type: Easing.OutQuad }
                                    }
                                    PauseAnimation { duration: (1 - ring.index) * 600 }
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: MosaicTheme.r(20)
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.lighter(callRow.tone, 1.2) }
                                GradientStop { position: 1; color: Qt.darker(callRow.tone, 1.5) }
                            }
                            SequentialAnimation on scale { // the heartbeat while it rings
                                running: callRow.ringing
                                loops: Animation.Infinite
                                NumberAnimation { from: 1; to: 1.06; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.06; to: 1; duration: 600; easing.type: Easing.InOutSine }
                            }
                            StyledText {
                                anchors.centerIn: parent
                                text: (root.eventText.match(/[A-Za-zÀ-ÿ0-9]/)?.[0] ?? "?").toUpperCase()
                                font.family: MosaicTheme.fontUi
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: "white"
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(200, Math.max(callName.implicitWidth, callSub.implicitWidth))
                        StyledText {
                            id: callName
                            width: parent.width
                            text: root.eventText
                            font.family: MosaicTheme.fontUi
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                        StyledText {
                            id: callSub
                            width: parent.width
                            text: root.eventSub + (callRow.ringing ? " · ligação" : "")
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                    RippleButton { // silence the ringing phone
                        visible: callRow.ringing
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 38
                        implicitHeight: 38
                        buttonRadius: 19
                        colBackground: Appearance.colors.colError
                        onClicked: {
                            phone.mute();
                            root.eventKind = "";
                        }
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "volume_off"
                                fill: 1
                                iconSize: 18
                                color: Appearance.colors.colOnError
                            }
                        }
                    }
                }
            }
            // the phone connected or left: its icon with a ring going out
            Component {
                id: phoneEvent
                Row {
                    spacing: 10
                    Item {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            radius: MosaicTheme.r(11)
                            color: "transparent"
                            border.width: 1.5
                            border.color: Appearance.colors.colPrimary
                            NumberAnimation on scale { from: 0.6; to: 1.9; duration: 1100; easing.type: Easing.OutCubic }
                            NumberAnimation on opacity { from: 0.9; to: 0; duration: 1100; easing.type: Easing.OutQuad }
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.eventIcon
                            iconSize: 18
                            fill: 1
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.eventText
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }
            Component {
                id: textEvent
                Row {
                    spacing: 8
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.eventIcon
                        iconSize: 18
                        fill: 1
                        color: root.eventKind === "battery" ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.eventText
                        font.family: MosaicTheme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }

            // ---------- notification bubble, melting out of the island ----------
            // A bubble drops out from under the island; while it is close, the goo
            // shader joins the two with a liquid neck. Idea from hyprdots' IsleDrip.
            Item {
                id: bubble
                anchors.fill: parent
                z: -1 // behind the island, so the mark and the time stay on top of the goo
                // the card is the start menu when it is open here, else the notifications
                readonly property bool showMenu: win.menuHere
                readonly property bool showNotes: win.notesHere && !showMenu
                readonly property bool open: (showMenu || showNotes || (root.hasNotifs && win.isFocusedScreen)) && notch.mode !== "compass"
                // life: 0 = tucked under the island, 1 = out (opens on a soft spring, closes with a quick slide)
                MosaicSpring { id: life; response: 0.72; damping: 0.96; springBack: false; closeMs: 420; target: bubble.open ? 1 : 0 }
                readonly property real g: Math.max(0, life.value)
                readonly property bool living: life.value > 0.005 || bubble.open
                // the compass takes over at once: no bubble half-way
                Connections {
                    target: notch
                    function onModeChanged() { if (notch.mode === "compass") life.settle(0); }
                }

                readonly property real cardW: showMenu ? 640 : showNotes ? 560 : 440
                property real shownH: 80
                Behavior on shownH { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Binding {
                    target: bubble
                    property: "shownH"
                    value: Math.min(notifList.contentHeight + 16, 460)
                    when: !bubble.showMenu && !bubble.showNotes && root.hasNotifs && notifList.contentHeight > 0
                }
                Binding {
                    target: bubble
                    property: "shownH"
                    value: menuLoader.item ? menuLoader.item.implicitHeight + 24 : 80
                    when: bubble.showMenu
                }
                Binding {
                    target: bubble
                    property: "shownH"
                    value: notesLoader.item ? notesLoader.item.implicitHeight + 24 : 80
                    when: bubble.showNotes
                }

                // the island as it is drawn right now (scale and hiding included)
                readonly property real isleW: notch.width * notch.scaleX
                readonly property real isleH: notch.height * notch.scaleY
                readonly property real isleTop: notch.y + notch.height / 2 - isleH / 2 + notch.hideY
                readonly property real base: isleTop + isleH
                readonly property real cx: width / 2
                // the bubble grows from a thin strip under the island into the card
                // then, once it is out, it melts into the island: it rises until it
                // touches it and the neck widens, so the two become one shape
                MosaicSpring { id: merge; response: 0.55; damping: 0.82; epsilon: 0.002; target: bubble.open && life.value > 0.9 ? 1 : 0 }
                readonly property real mg: Math.max(0, merge.value)
                readonly property real bw: bubble.mix(isleW * 0.42, cardW, g)
                readonly property real bh: bubble.mix(18, shownH, g)
                readonly property real by: bubble.mix(base - 16, base + 12, g) - 14 * mg
                readonly property real bx: cx - bw / 2
                function mix(a, b, t) { return a + (b - a) * t; }

                ShaderEffect {
                    anchors.fill: parent
                    visible: bubble.living
                    fragmentShader: Qt.resolvedUrl("shaders/goo.frag.qsb")
                    property vector2d size: Qt.vector2d(width, height)
                    property vector4d island: Qt.vector4d(bubble.cx, bubble.isleTop + bubble.isleH / 2, bubble.isleW / 2, bubble.isleH / 2)
                    property vector4d twin: Qt.vector4d(bubble.cx, bubble.base - 4, bubble.mix(Math.max(12, Math.min(bubble.isleW - 44, 260) / 2), bubble.isleW / 2, bubble.mg), 4 + 4 * bubble.mg)
                    property vector4d body: Qt.vector4d(bubble.cx, bubble.by + bubble.bh / 2, bubble.bw / 2, bubble.bh / 2)
                    property real islandRadius: notch.cornerRadius * notch.scaleY
                    property real bodyRadius: MosaicTheme.r(Math.min(22, bubble.bh / 2))
                    property real fuse: (22 + 10 * bubble.mg) * Math.max(0.35, MosaicTheme.roundness) // boxy themes melt with tighter curves
                    property real islandLeft: bubble.cx - bubble.isleW / 2
                    property real islandWidth: bubble.isleW
                    property color stop0: root.opaque(root.washStop(0, 0))
                    property color stop1: root.opaque(root.washStop(1, 0))
                    property color stop2: root.opaque(root.washStop(2, 0))
                    property real fillAlpha: root.islandAlpha
                    property color strokeColor: root.opaque(root.outlineColor)
                    property real strokeAlpha: root.outlineColor.a
                    property real strokeWidth: MosaicTheme.brutal ? MosaicTheme.border : 1
                    property vector2d shadowOffset: Qt.vector2d(MosaicTheme.shadow, MosaicTheme.shadow)
                    property color shadowColor: root.opaque(MosaicTheme.shadowColor)
                    property real shadowAlpha: MosaicTheme.brutal ? 1 : 0
                    property real grain: MosaicTheme.grainIsland
                }

                // the notifications themselves, laid out at full width and revealed by the bubble
                Item {
                    id: bubbleClip
                    x: bubble.bx
                    y: bubble.by
                    width: bubble.living ? bubble.bw : 0
                    height: bubble.living ? bubble.bh : 0
                    clip: true
                    NotificationListView {
                        id: notifList
                        visible: !bubble.showMenu && !bubble.showNotes
                        x: (bubble.bw - width) / 2
                        y: 8
                        width: bubble.cardW - 16
                        height: contentHeight
                        opacity: Math.pow(bubble.g, 2)
                        popup: true
                        expandAll: true
                    }
                    Loader {
                        id: notesLoader
                        active: bubble.showNotes
                        x: (bubble.bw - width) / 2
                        y: 12
                        width: bubble.cardW - 24
                        opacity: Math.pow(bubble.g, 2)
                        sourceComponent: Notes {
                            onDone: root.notesOpen = false
                            Component.onCompleted: focusEditor()
                        }
                    }
                    Loader {
                        id: menuLoader
                        active: bubble.showMenu
                        x: (bubble.bw - width) / 2
                        y: 12
                        width: bubble.cardW - 24
                        opacity: Math.pow(bubble.g, 2)
                        sourceComponent: StartMenu {
                            recents: recentApps
                            onDone: GlobalStates.searchOpen = false
                            Component.onCompleted: focusSearch()
                        }
                    }
                }
            }

            // ---------- panel ----------
            Component {
                id: panelView
                ColumnLayout {
                    spacing: 6 + MosaicTheme.shadow
                    // brutal themes: leave room on the right and bottom for the hard shadows
                    width: parent ? parent.width - MosaicTheme.shadow : implicitWidth

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
                                    font.family: MosaicTheme.fontDisplay
                                    font.pixelSize: 34
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 13
                                    text: DateTime.longDate
                                    font.family: MosaicTheme.fontUi
                                    font.pixelSize: 13
                                    color: Appearance.colors.colOnLayer0
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                }
                                // the tray (it left the dock), on the other side of the time
                                Bar.SysTray {
                                    id: tray
                                    visible: SystemTray.items.values.length > 0
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 22
                                    invertSide: false // menus open downwards, under the island
                                    showSeparator: false
                                }
                                // while a tray menu is open, a click in it must not close the panel
                                Binding {
                                    target: win
                                    property: "trayBusy"
                                    value: tray.activeMenu !== null || tray.trayOverflowOpen
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
                                        font.family: MosaicTheme.fontDisplay
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
                                    font.family: MosaicTheme.fontUi
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
                                    // record the whole screen; while recording it turns red, pulses and shows the time
                                    icon: root.recording ? "stop" : "screen_record"
                                    label: root.recording ? `${Math.floor(root.recordSeconds / 60)}:${String(root.recordSeconds % 60).padStart(2, "0")}` : "Gravar"
                                    toggled: root.recording
                                    alert: root.recording
                                    onClicked: {
                                        win.setOpen(false);
                                        root.toggleRecording();
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
                                    icon: "sticky_note_2"
                                    label: "Notas"
                                    onClicked: {
                                        win.setOpen(false);
                                        root.toggleNotes();
                                    }
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
                                    // KDE Connect gives no number while the phone is away
                                    visible: Battery.available && !isNaN(Battery.percentage)
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
                edgeMargin: notch.y + notch.height + 8
            }
        }
    }

    // A block inside the island, like a bar group, in one Matugen tone
    component Block: Rectangle {
        id: block
        property color tint: Appearance.colors.colLayer1
        property color tint2: tint // the tone it flows into, left to right (flat in brutal themes)
        radius: Appearance.rounding.small
        border.width: MosaicTheme.border
        border.color: MosaicTheme.ink
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: block.tint }
            GradientStop { position: 1; color: MosaicTheme.brutal ? block.tint : block.tint2 }
        }
        HardShadow {}
    }

    // A round quick tool with a caption under it: fixed cell, icon truly centered
    component QuickTool: Item {
        id: tool
        required property string icon
        required property string label
        property bool toggled: false
        property bool alert: false // red and pulsing (recording)
        signal clicked()
        signal altClicked() // right click
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
            buttonRadius: MosaicTheme.brutal ? MosaicTheme.r(21) : 21 // brutal themes: square keys
            toggled: tool.toggled
            colBackground: Appearance.colors.colLayer2
            colBackgroundToggled: tool.alert ? Appearance.colors.colError : Appearance.colors.colPrimary
            colBackgroundToggledHover: tool.alert ? Qt.lighter(Appearance.colors.colError, 1.1) : Appearance.colors.colPrimaryHover
            onClicked: tool.clicked()
            altAction: () => tool.altClicked()
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: tool.icon
                    iconSize: 20
                    color: tool.alert ? Appearance.colors.colOnError : tool.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
            }
        }
        // alert: a red ring growing out of the button and fading, again and again
        Rectangle {
            visible: tool.alert
            anchors.centerIn: toolButton
            width: toolButton.width
            height: toolButton.height
            radius: toolButton.buttonRadius
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colError
            SequentialAnimation on scale {
                running: tool.alert
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 1.35; duration: 1100; easing.type: Easing.OutCubic }
            }
            SequentialAnimation on opacity {
                running: tool.alert
                loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 0; duration: 1100; easing.type: Easing.OutQuad }
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: toolButton.bottom
            anchors.topMargin: 4
            text: tool.label
            font.family: tool.alert ? "JetBrains Mono" : "Space Grotesk"
            font.pixelSize: 11
            font.weight: tool.alert ? Font.Bold : Font.Normal
            color: tool.alert ? Appearance.colors.colError : Appearance.colors.colSubtext
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
            radius: MosaicTheme.r(8)
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
                const w = width, h = height, r = MosaicTheme.r(7);
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
