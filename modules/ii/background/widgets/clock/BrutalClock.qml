import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mosaic.island

// Mosaic OS: the desktop clock in brutal themes (Gruvbox): a solid slab with the
// time in fat numbers, a thick cream outline and a big hard orange shadow; the
// date is a tilted sticker stuck on the corner, and the Mosaic mark sits on top.
// Every new minute the slab goes "thump": it sinks into its shadow and comes back.
Item {
    id: clock
    readonly property real shadowSize: 10
    implicitWidth: slab.width + shadowSize + 8
    implicitHeight: slab.height + shadowSize + sticker.height / 2 + 4

    Rectangle {
        id: slab
        width: time.implicitWidth + 56
        height: time.implicitHeight + 28
        radius: MosaicTheme.r(18)
        color: MosaicTheme.slab
        border.width: 3
        border.color: MosaicTheme.ink
        transform: Translate { x: hard.sinkShift; y: hard.sinkShift }
        HardShadow {
            id: hard
            size: clock.shadowSize
            sink: thump.running
        }

        StyledText {
            id: time
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            text: DateTime.time
            font.family: MosaicTheme.fontUi
            font.pixelSize: 112
            font.weight: Font.Black
            font.letterSpacing: -4
            color: MosaicTheme.ink
        }
        // the Mosaic mark, perched on the top edge
        Mascot {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.top
            size: 30
            showFace: false
        }
    }

    // the date, a sticker stuck crooked on the bottom-left corner
    Rectangle {
        id: sticker
        x: -6
        y: slab.height - height / 2
        width: dateText.implicitWidth + 24
        height: dateText.implicitHeight + 12
        radius: MosaicTheme.r(6)
        rotation: -4
        color: Appearance.colors.colPrimary
        border.width: 2
        border.color: MosaicTheme.slab
        HardShadow { size: 4; color: MosaicTheme.slab }
        StyledText {
            id: dateText
            anchors.centerIn: parent
            text: Qt.locale().toString(DateTime.clock.date, "ddd dd/MM").toUpperCase().replace(".", "")
            font.family: "JetBrains Mono"
            font.pixelSize: 18
            font.weight: Font.Black
            color: Appearance.colors.colOnPrimary
        }
    }

    // every new minute: thump
    Connections {
        target: DateTime
        function onTimeChanged() { thump.restart(); }
    }
    Timer {
        id: thump
        interval: 140
    }
}
