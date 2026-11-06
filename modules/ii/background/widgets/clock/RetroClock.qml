import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Mosaic OS: the desktop clock in retro themes (Horizonte), set like the first
// screen of the Claude Opus 5.5 page: the date in small spaced capitals on top,
// the time big in the theme's serif (Fraunces), and under it a dotted leader
// line, like the page's index, running from "(weekday)" to the period of the day.
// No box behind it: it sits right on the wallpaper, with a soft dark halo so it
// reads over the bright sky.
Item {
    id: clock
    implicitWidth: Math.max(time.implicitWidth, 360)
    implicitHeight: column.implicitHeight
    readonly property color cream: MosaicTheme.ink

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale().toString(DateTime.clock.date, "d 'de' MMMM, yyyy").toUpperCase()
            font.family: MosaicTheme.fontUi
            font.pixelSize: 15
            font.weight: Font.Medium
            font.letterSpacing: 2.4
            color: Qt.rgba(clock.cream.r, clock.cream.g, clock.cream.b, 0.82)
            style: Text.Raised
            styleColor: "#40000000"
        }
        StyledText {
            id: time
            anchors.horizontalCenter: parent.horizontalCenter
            text: DateTime.time
            font.family: MosaicTheme.fontDisplay
            font.pixelSize: 128
            font.weight: Font.Normal
            font.letterSpacing: -3
            color: clock.cream
            style: Text.Raised
            styleColor: "#55000000"
        }
        // (qui) ·························· tarde
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: time.implicitWidth * 0.82
            height: 18
            StyledText {
                id: day
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "(" + Qt.locale().toString(DateTime.clock.date, "ddd").replace(".", "") + ")"
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                color: Qt.rgba(clock.cream.r, clock.cream.g, clock.cream.b, 0.75)
            }
            // the dotted leader: a row of 1 px dots, as many as fit
            Row {
                anchors.left: day.right
                anchors.right: period.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                clip: true
                Repeater {
                    model: Math.max(0, Math.floor((parent.width + 3) / 4))
                    Rectangle {
                        width: 1
                        height: 1
                        color: Qt.rgba(clock.cream.r, clock.cream.g, clock.cream.b, 0.55)
                    }
                }
            }
            StyledText {
                id: period
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                readonly property int hour: DateTime.clock.date.getHours()
                text: hour < 6 ? "madrugada" : hour < 12 ? "manhã" : hour < 18 ? "tarde" : "noite"
                font.family: MosaicTheme.fontDisplay
                font.pixelSize: 15
                color: clock.cream
            }
        }
    }
}
