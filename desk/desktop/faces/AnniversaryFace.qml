// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A N N I V E R S A R Y   F A C E                                        │
// │   the days since a date · Mosaic OS                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"
import "."
import "./analogue"
import "./sticker"

// Mosaic OS: the "Dias juntos" widget the ii had, brought to the desk in the
// three styles. The row keeps the date (`since`, YYYY-MM-DD) and the words
// (`label`); both come from the old widget's config on the first run.
//   modern    the count on the glass, a heart for a mark; wide, the months
//             and how long until the next one
//   analogue  a calendar leaf: the words on the ribbon, the count, the date
//   sticker   a pink cut-out with the count, the words on a tag
Item {
    id: root

    property string style: "modern"
    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property var row: null
    property string seed: root.row && root.row.key ? root.row.key : "anniversary"

    readonly property string since: root.row && typeof root.row.since === "string" && root.row.since !== ""
        ? root.row.since : "2026-07-22"
    readonly property string words: root.row && typeof root.row.label === "string" && root.row.label !== ""
        ? root.row.label : "dias juntos"

    // midnight to midnight, so the count turns at the start of the day
    readonly property date start: {
        const parts = root.since.split("-").map(Number)
        return new Date(parts[0], (parts[1] || 1) - 1, parts[2] || 1)
    }
    readonly property int days: {
        const now = clock.date
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        return Math.max(0, Math.round((today - root.start) / 86400000))
    }
    // whole months since the date, and the day the next one is reached
    readonly property int months: {
        const now = clock.date
        let count = (now.getFullYear() - root.start.getFullYear()) * 12 + now.getMonth() - root.start.getMonth()
        if (now.getDate() < root.start.getDate())
            count -= 1
        return Math.max(0, count)
    }
    readonly property int toNext: {
        const next = new Date(root.start.getFullYear(), root.start.getMonth() + root.months + 1, root.start.getDate())
        const now = clock.date
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        return Math.max(0, Math.round((next - today) / 86400000))
    }
    readonly property string sinceLabel: `desde ${Theme.fmt(root.start, "d 'de' MMMM")}`
    readonly property string monthsLabel: root.months === 1 ? "1 mês" : `${root.months} meses`
    readonly property string nextLabel: root.toNext === 0 ? "é hoje!"
        : root.toNext === 1 ? `amanhã fazem ${root.months + 1} meses`
        : `faltam ${root.toNext} dias para ${root.months + 1} meses`

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.style === "analogue" ? leaf : root.style === "sticker" ? cut : glass
    }

    // ── MODERN ──────────────────────────────────────────────────────────────

    Component {
        id: glass

        WidgetFace {
            ink: root.ink
            label: root.words
            reading: `${root.days}`
            note: root.sinceLabel
            extraShare: root.family === "4x2" ? 0.5 : 0

            Text {
                anchors.centerIn: parent
                text: "󰋑"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: Theme.red
            }

            extra: [
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 6
                    visible: root.family === "4x2"

                    Text {
                        width: parent.width
                        text: root.monthsLabel
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: root.ink.text
                        elide: Text.ElideRight
                    }

                    // how far into the current month together
                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: root.ink.dim

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Theme.red
                            width: parent.width * Math.max(0.04, 1 - root.toNext / 30)
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.nextLabel
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.ink.muted
                        elide: Text.ElideRight
                    }
                }
            ]
        }
    }

    // ── ANALOGUE ────────────────────────────────────────────────────────────

    Component {
        id: leaf

        Instrument {
            family: root.family
            ink: root.ink

            Leaf {
                anchors.centerIn: parent
                ink: root.ink
                width: Math.min(parent.width, parent.height * 0.74)
                height: parent.height
                month: root.words.toUpperCase()
                day: `${root.days}`
                weekday: root.family === "4x2" ? `${root.monthsLabel} · ${root.sinceLabel}` : root.sinceLabel
            }
        }
    }

    // ── STICKER ─────────────────────────────────────────────────────────────

    Component {
        id: cut

        Spread {
            family: root.family
            ink: root.ink
            seed: root.seed
            hue: Theme.red
            reading: root.words
            note: root.family === "4x2" ? root.nextLabel : root.sinceLabel

            Tone { id: tone; hue: Theme.red }

            Cut {
                id: heart

                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height
                shape: "soft"
                seed: root.seed
                fill: tone.fill

                Column {
                    anchors.centerIn: parent
                    spacing: -heart.side * 0.04

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰋑"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(heart.side * 0.16)
                        color: tone.deep
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${root.days}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(heart.side * (root.days > 999 ? 0.34 : 0.44))
                        font.weight: Font.Bold
                        color: tone.deep
                    }
                }
            }

            Dot {
                live: false
                x: parent.width * 0.68
                y: -parent.height * 0.02
                width: parent.width * 0.34
                height: width
                seed: root.seed + "months"
                hue: root.ink.yellow
                glyph: `${root.months}m`
            }
        }
    }
}
