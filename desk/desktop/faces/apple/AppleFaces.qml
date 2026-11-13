// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P L E   F A C E S                                                  │
// │   the macOS theme's widgets · Mosaic OS                                  │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// Mosaic OS: the widgets of the macOS theme, drawn after macOS's own: the
// Weather one on its sky, Calendar with the weekday in red, the analogue Clock,
// Music over its blurred cover, Batteries-style rings for the system and for
// Claude, and "Dias juntos" as a calendar card. White type in Inter (the free
// cousin of SF Pro), on the theme's liquid glass. Small (2×2) and wide (4×2);
// any other module or size falls back to the Modern faces (Face.qml asks
// `supports`).
Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var row: null

    readonly property bool wide: root.family === "4x2"
    readonly property real pad: Math.round(Math.min(root.width, root.height) * 0.085) + 2
    readonly property color white: "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.62)
    readonly property color red: "#ff453a"
    readonly property color orange: "#ff9f0a"
    readonly property color green: "#30d158"
    readonly property string ui: Theme.fontFamily
    readonly property string display: Theme.fontDisplay

    readonly property var components: ({
        weather: weather, calendar: calendar, clock: clock, media: media,
        stats: stats, claude: claude, anniversary: anniversary
    })

    // what Face.qml checks before choosing these faces
    function supports(id: string, family: string): bool {
        return root.components[id] !== undefined && (family === "2x2" || family === "4x2")
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.components[root.moduleId] ?? null
    }

    // a ring, as in the Batteries widget
    component Ring: Item {
        id: ring
        property real value: 0
        property color tint: root.green
        property string glyph: ""
        property real thickness: Math.max(3, width * 0.09)
        default property alias inner: centre.data
        Canvas {
            anchors.fill: parent
            property real v: Math.max(0, Math.min(1, ring.value))
            onVChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const r = width / 2 - ring.thickness / 2
                ctx.lineWidth = ring.thickness
                ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16)
                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2); ctx.stroke()
                ctx.strokeStyle = ring.tint
                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * v); ctx.stroke()
            }
        }
        Item {
            id: centre
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                visible: ring.glyph !== ""
                text: ring.glyph
                font.family: Theme.fontMono
                font.pixelSize: Math.round(ring.width * 0.36)
                color: root.white
            }
        }
    }

    // ── WEATHER: the sky behind it, the place, the big temperature ──────────
    Component {
        id: weather
        Item {
            id: w
            readonly property int hour: clockW.date.getHours()
            readonly property bool night: w.hour < 6 || w.hour >= 18
            readonly property string sky: {
                const d = WeatherService.description.toLowerCase()
                if (/chuv|garoa|trovo|tempest|aguaceiro/.test(d)) return "rain"
                if (/nubl|encob|nuve|neblin|nevoeiro/.test(d)) return "cloud"
                return "clear"
            }
            readonly property var colors: w.night
                ? (w.sky === "clear" ? ["#0b1736", "#25386b"] : ["#1b2433", "#3a4658"])
                : (w.sky === "rain" ? ["#3d4b5c", "#68798c"] : w.sky === "cloud" ? ["#4a6587", "#8aa3bf"] : ["#1d6fd8", "#5fb3f2"])
            SystemClock { id: clockW; precision: SystemClock.Minutes }
            Rectangle {
                anchors.fill: parent
                radius: Theme.desktopRadius
                opacity: 0.88
                gradient: Gradient {
                    GradientStop { position: 0; color: w.colors[0] }
                    GradientStop { position: 1; color: w.colors[1] }
                }
            }
            Column {
                x: root.pad
                y: root.pad - 2
                spacing: -2
                Row {
                    spacing: 4
                    Text {
                        text: WeatherService.place || "Clima"
                        font.family: root.ui; font.pixelSize: 15; font.weight: Font.DemiBold
                        color: root.white
                        width: Math.min(implicitWidth, (root.wide ? root.width / 2 : root.width) - 2 * root.pad - 14)
                        elide: Text.ElideRight
                    }
                    Text { text: "󰆋"; font.family: Theme.fontMono; font.pixelSize: 11; color: root.white; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    text: WeatherService.available ? `${WeatherService.temperature}°` : "--"
                    font.family: root.display; font.pixelSize: 46; font.weight: Font.Light
                    color: root.white
                }
            }
            Column {
                x: root.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.pad - 2
                spacing: 1
                Text {
                    text: WeatherService.glyph
                    font.family: Theme.fontMono; font.pixelSize: 22
                    color: w.sky === "clear" && !w.night ? "#ffd60a" : root.white
                }
                Text {
                    text: WeatherService.description
                    width: (root.wide ? root.width / 2 : root.width) - 2 * root.pad
                    elide: Text.ElideRight
                    font.family: root.ui; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: root.white
                }
                Text {
                    text: WeatherService.available ? `Máx.: ${WeatherService.high}° Mín.: ${WeatherService.low}°` : ""
                    font.family: root.ui; font.pixelSize: 13; font.weight: Font.Medium
                    color: root.white
                }
            }
            // wide: the next hours, as on the Mac
            Row {
                visible: root.wide
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: root.wide ? (WeatherService.hourly ?? []).slice(0, 5) : []
                    Column {
                        required property var modelData
                        width: 30
                        spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: `${modelData.hour}`.padStart(2, "0"); font.family: root.ui; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.dim }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.glyph; font.family: Theme.fontMono; font.pixelSize: 17; color: root.white }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: `${modelData.temperature}°`; font.family: root.ui; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.white }
                    }
                }
            }
        }
    }

    // ── CALENDAR: the weekday in red, the date, what is next ────────────────
    Component {
        id: calendar
        Item {
            id: cal
            readonly property date today: clockC.date
            readonly property int dueToday: TasksService.pendingOn(TasksService.todayKey)
            SystemClock { id: clockC; precision: SystemClock.Minutes }
            Column {
                x: root.pad
                y: root.pad - 2
                spacing: -4
                Text {
                    text: Theme.fmt(cal.today, "dddd").toUpperCase()
                    font.family: root.ui; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.4
                    color: root.red
                }
                Text {
                    text: `${cal.today.getDate()}`
                    font.family: root.display; font.pixelSize: 52; font.weight: Font.Normal
                    color: root.white
                }
            }
            Column {
                x: root.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.pad - 2
                width: (root.wide ? root.width / 2 : root.width) - 2 * root.pad
                spacing: 2
                Rectangle { visible: TasksService.next !== null; width: 3; height: 0 }
                Text {
                    width: parent.width
                    text: cal.dueToday > 0 ? (cal.dueToday === 1 ? "1 tarefa para hoje" : `${cal.dueToday} tarefas para hoje`)
                        : TasksService.next ? TasksService.next.text : "Nenhum evento hoje"
                    elide: Text.ElideRight
                    font.family: root.ui; font.pixelSize: 13; font.weight: Font.DemiBold
                    color: cal.dueToday > 0 || TasksService.next ? root.white : root.dim
                }
                Text {
                    width: parent.width
                    visible: cal.dueToday === 0 && TasksService.next !== null
                    text: TasksService.next ? TasksService.dueLabel(TasksService.next.due) : ""
                    font.family: root.ui; font.pixelSize: 12
                    color: root.dim
                }
            }
            // wide: the month, today in a red circle
            Grid {
                visible: root.wide
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                columns: 7
                columnSpacing: 2
                rowSpacing: 1
                readonly property var cells: {
                    const y = cal.today.getFullYear(), m = cal.today.getMonth()
                    const shift = (new Date(y, m, 1).getDay() + 6) % 7
                    const total = new Date(y, m + 1, 0).getDate()
                    const out = ["S", "T", "Q", "Q", "S", "S", "D"]
                    for (let i = 0; i < shift; i++) out.push("")
                    for (let d = 1; d <= total; d++) out.push(`${d}`)
                    return out
                }
                Repeater {
                    model: root.wide ? parent.cells : []
                    Item {
                        required property var modelData
                        required property int index
                        width: 19
                        height: 17
                        readonly property bool isToday: modelData === `${cal.today.getDate()}` && index >= 7
                        Rectangle { anchors.centerIn: parent; width: 17; height: 17; radius: 8.5; color: root.red; visible: parent.isToday }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.family: root.ui
                            font.pixelSize: 10
                            font.weight: index < 7 || parent.isToday ? Font.Bold : Font.Medium
                            color: index < 7 ? root.dim : root.white
                        }
                    }
                }
            }
        }
    }

    // ── CLOCK: the analogue dial, an orange second hand ─────────────────────
    Component {
        id: clock
        Item {
            id: ck
            readonly property date now: clockK.date
            // the row's `digital`: the lock screen's clock instead of the dial
            readonly property bool digital: root.row && root.row.digital === true
            SystemClock { id: clockK; precision: ck.digital ? SystemClock.Minutes : SystemClock.Seconds }

            // ── digital: the date over the time, in the lock's type ──
            Column {
                visible: ck.digital
                anchors.centerIn: parent
                width: parent.width - 2 * root.pad
                spacing: -Math.round(root.height * 0.04)
                // both lines shrink to fit the card (the time is long in 12-hour mode)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 9
                    text: Theme.fmt(ck.now, root.wide ? "dddd, d 'de' MMMM" : "ddd, d 'de' MMM").replace(".", "")
                    font.family: root.display
                    font.pixelSize: Math.round(root.height * 0.095)
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.88)
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 20
                    text: Theme.fmt(ck.now, SettingsService.clockFormat)
                    font.family: root.display
                    font.pixelSize: Math.round(Math.min(root.height * 0.46, root.width * (root.wide ? 0.3 : 0.36)))
                    font.weight: Font.Bold
                    font.letterSpacing: -root.height * 0.006
                    color: Qt.rgba(1, 1, 1, 0.92)
                }
            }

            Item {
                id: dial
                visible: !ck.digital
                width: Math.min(parent.height, root.wide ? parent.width / 2 : parent.width) - root.pad * 1.2
                height: width
                x: root.wide ? root.pad * 0.6 : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: width / 2; color: "#1c1c1e"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12) }
                Repeater {
                    model: 12
                    Text {
                        required property int index
                        readonly property real a: (index + 1) / 12 * Math.PI * 2
                        x: dial.width / 2 + Math.sin(a) * dial.width * 0.38 - width / 2
                        y: dial.height / 2 - Math.cos(a) * dial.width * 0.38 - height / 2
                        text: `${index + 1}`
                        font.family: root.ui
                        font.pixelSize: Math.round(dial.width * 0.11)
                        font.weight: Font.DemiBold
                        color: root.white
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: dial.height * 0.64
                    text: Theme.fmt(ck.now, "ddd").toUpperCase().replace(".", "")
                    font.family: root.ui; font.pixelSize: Math.round(dial.width * 0.075); font.weight: Font.Bold
                    color: root.dim
                }
                Rectangle { // hour
                    id: hourHand
                    width: Math.max(4, dial.width * 0.04); height: dial.width * 0.26; radius: width / 2; color: root.white
                    x: dial.width / 2 - width / 2; y: dial.height / 2 - height
                    transform: Rotation { origin.x: hourHand.width / 2; origin.y: hourHand.height; angle: (ck.now.getHours() % 12 + ck.now.getMinutes() / 60) * 30 }
                }
                Rectangle { // minute
                    id: minuteHand
                    width: Math.max(3, dial.width * 0.03); height: dial.width * 0.38; radius: width / 2; color: root.white
                    x: dial.width / 2 - width / 2; y: dial.height / 2 - height
                    transform: Rotation { origin.x: minuteHand.width / 2; origin.y: minuteHand.height; angle: (ck.now.getMinutes() + ck.now.getSeconds() / 60) * 6 }
                }
                Rectangle { // second
                    id: secondHand
                    width: 1.5; height: dial.width * 0.44; color: root.orange
                    x: dial.width / 2 - width / 2; y: dial.height / 2 - height * 0.82
                    transform: Rotation { origin.x: secondHand.width / 2; origin.y: secondHand.height * 0.82; angle: ck.now.getSeconds() * 6 }
                }
                Rectangle { anchors.centerIn: parent; width: dial.width * 0.05; height: width; radius: width / 2; color: root.orange }
            }
            Column {
                visible: root.wide && !ck.digital
                anchors.left: dial.right
                anchors.leftMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text { text: Theme.fmt(ck.now, "dddd"); font.family: root.ui; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.red }
                Text { text: Theme.fmt(ck.now, "HH:mm"); font.family: root.display; font.pixelSize: 44; font.weight: Font.Light; color: root.white }
                Text { text: Theme.fmt(ck.now, "d 'de' MMMM"); font.family: root.ui; font.pixelSize: 13; color: root.dim }
            }
        }
    }

    // ── MUSIC: the blurred cover behind, the cover, the song ────────────────
    Component {
        id: media
        Item {
            id: mu
            Image {
                id: cover
                anchors.fill: parent
                source: MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
            }
            Rectangle { id: coverMask; anchors.fill: parent; radius: Theme.desktopRadius; visible: false; layer.enabled: true }
            MultiEffect {
                anchors.fill: parent
                source: cover
                visible: cover.status === Image.Ready
                autoPaddingEnabled: false // the blur stays inside the card (else it bleeds out as glass)
                blurEnabled: true; blur: 1; blurMax: 48
                brightness: -0.18; saturation: 0.25
                maskEnabled: true; maskSource: coverMask
                opacity: 0.9
            }
            Rectangle {
                x: root.pad; y: root.pad
                width: root.wide ? 62 : 56; height: width; radius: 9
                color: Qt.rgba(1, 1, 1, 0.12)
                clip: true
                Image { anchors.fill: parent; source: MediaService.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false; id: art }
                Rectangle { id: artMask; anchors.fill: parent; radius: 9; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: artMask; visible: art.status === Image.Ready }
                Text { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "󰎈"; font.family: Theme.fontMono; font.pixelSize: 24; color: root.dim }
            }
            Rectangle { // the Music app's mark
                anchors.right: parent.right; anchors.rightMargin: root.pad
                y: root.pad
                width: 20; height: 20; radius: 5
                gradient: Gradient { GradientStop { position: 0; color: "#fc5c7d" } GradientStop { position: 1; color: "#fa233b" } }
                Text { anchors.centerIn: parent; text: "󰝚"; font.family: Theme.fontMono; font.pixelSize: 12; color: "white" }
            }
            Column {
                x: root.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.pad - 2
                width: parent.width - 2 * root.pad - (root.wide ? 120 : 0)
                spacing: 1
                Text {
                    width: parent.width
                    text: MediaService.available ? MediaService.title : "Nada tocando"
                    elide: Text.ElideRight
                    font.family: root.ui; font.pixelSize: 14; font.weight: Font.Bold
                    color: root.white
                }
                Text {
                    width: parent.width
                    text: MediaService.artist
                    visible: text !== ""
                    elide: Text.ElideRight
                    font.family: root.ui; font.pixelSize: 13
                    color: root.dim
                }
            }
            Row {
                visible: root.wide
                anchors.right: parent.right; anchors.rightMargin: root.pad
                anchors.bottom: parent.bottom; anchors.bottomMargin: root.pad + 2
                spacing: 18
                Repeater {
                    model: [{ g: "󰒮", f: () => MediaService.previous() }, { g: MediaService.playing ? "󰏤" : "󰐊", f: () => MediaService.toggle() }, { g: "󰒭", f: () => MediaService.next() }]
                    Text {
                        required property var modelData
                        text: modelData.g
                        font.family: Theme.fontMono; font.pixelSize: 22
                        color: root.white
                        TapHandler { onTapped: parent.modelData.f() }
                    }
                }
            }
        }
    }

    // ── SYSTEM: Batteries-style rings ───────────────────────────────────────
    Component {
        id: stats
        Item {
            readonly property var rings: [
                { v: StatsService.cpu / 100, g: "󰍛", l: "CPU" },
                { v: StatsService.memoryFraction, g: "󰘚", l: "RAM" },
                { v: StatsService.temperature ? Math.min(1, StatsService.temperature / 100) : 0, g: "󰔏", l: StatsService.temperature ? `${Math.round(StatsService.temperature)}°` : "TEMP" },
                { v: StatsService.swapFraction ?? 0, g: "󰾴", l: "SWAP" }
            ]
            Grid {
                anchors.centerIn: parent
                columns: root.wide ? 4 : 2
                columnSpacing: root.wide ? 22 : 14
                rowSpacing: root.wide ? 0 : 14
                Repeater {
                    model: parent.parent.rings
                    Column {
                        required property var modelData
                        spacing: 6
                        Ring {
                            width: root.wide ? 58 : Math.round((root.height - 2 * root.pad - 14) / 2)
                            height: width
                            value: modelData.v
                            tint: modelData.v > 0.85 ? root.red : modelData.v > 0.6 ? "#ffd60a" : root.green
                            glyph: modelData.g
                        }
                        Text {
                            visible: root.wide
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.l === "CPU" || modelData.l === "RAM" || modelData.l === "SWAP" ? `${Math.round(modelData.v * 100)}%` : modelData.l
                            font.family: root.ui; font.pixelSize: 13; font.weight: Font.DemiBold
                            color: root.white
                        }
                    }
                }
            }
        }
    }

    // ── CLAUDE: one ring for the 5-hour block ───────────────────────────────
    Component {
        id: claude
        Item {
            Ring {
                id: cring
                width: root.wide ? root.height - 2 * root.pad : Math.min(root.width, root.height) * 0.5
                height: width
                x: root.wide ? root.pad : (parent.width - width) / 2
                y: root.wide ? root.pad : root.pad
                value: ClaudeService.gauge
                tint: ClaudeService.gauge >= 0.85 ? root.red : "#d97757"
                ClaudeMark { anchors.centerIn: parent; width: parent.width * 0.38; height: width; color: "#d97757" }
            }
            Column {
                anchors.left: root.wide ? cring.right : parent.left
                anchors.leftMargin: root.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.pad - 2
                spacing: 1
                Text { text: "Claude Code"; font.family: root.ui; font.pixelSize: 13; font.weight: Font.Bold; color: "#d97757" }
                Text {
                    text: ClaudeService.measured ? ClaudeService.percent(ClaudeService.gauge) : `${ClaudeService.compact(ClaudeService.blockTokens)} tokens`
                    font.family: root.display; font.pixelSize: root.wide ? 30 : 20; font.weight: Font.Medium; color: root.white
                }
                Text { text: ClaudeService.resetsIn.replace("resets in", "renova em").replace("resets now", "renova agora"); font.family: root.ui; font.pixelSize: 12; color: root.dim }
            }
        }
    }

    // ── DIAS JUNTOS: a calendar card ────────────────────────────────────────
    Component {
        id: anniversary
        Item {
            id: an
            readonly property string since: root.row && root.row.since ? root.row.since : "2026-07-22"
            readonly property string words: root.row && root.row.label ? root.row.label : "dias juntos"
            readonly property date start: { const p = an.since.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]) }
            readonly property int days: {
                const n = clockA.date
                return Math.max(0, Math.round((new Date(n.getFullYear(), n.getMonth(), n.getDate()) - an.start) / 86400000))
            }
            SystemClock { id: clockA; precision: SystemClock.Hours }
            Column {
                x: root.pad
                y: root.pad - 2
                spacing: -4
                Row {
                    spacing: 5
                    Text { text: "󰋑"; font.family: Theme.fontMono; font.pixelSize: 13; color: "#ff375f"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: an.words.toUpperCase(); font.family: root.ui; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.4; color: "#ff375f" }
                }
                Text { text: `${an.days}`; font.family: root.display; font.pixelSize: 52; color: root.white }
            }
            Text {
                x: root.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.pad - 2
                text: `desde ${Theme.fmt(an.start, "d 'de' MMMM 'de' yyyy")}`
                font.family: root.ui; font.pixelSize: 12; font.weight: Font.Medium
                color: root.dim
            }
        }
    }
}
