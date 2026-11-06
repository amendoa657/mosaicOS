import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"

    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth

    StyledDropShadow {
        visible: !MosaicTheme.brutal
        target: backgroundShape
    }

    // Mosaic OS: brutal themes make it a crooked square sticker with a hard shadow
    MaterialShape {
        visible: MosaicTheme.brutal
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.topMargin: 8
        anchors.rightMargin: -8
        anchors.bottomMargin: -8
        rotation: backgroundShape.rotation
        shape: MaterialShape.Shape.Square
        color: MosaicTheme.shadowColor
        implicitSize: 200
    }

    MaterialShape {
        id: backgroundShape
        anchors.fill: parent
        rotation: MosaicTheme.brutal ? -3 : 0
        borderWidth: MosaicTheme.brutal ? 3 : 0
        borderColor: MosaicTheme.ink
        shape: MosaicTheme.brutal ? MaterialShape.Shape.Square : MaterialShape.Shape.Pill
        color: Appearance.colors.colPrimaryContainer
        implicitSize: 200

        StyledText {
            font {
                pixelSize: 80
                family: Appearance.font.family.expressive
                weight: Font.Medium
            }
            color: Appearance.colors.colPrimary
            text: Weather.data?.temp.substring(0,Weather.data?.temp.length - 1) ?? "--°"
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 16
                topMargin: 20
            }
        }

        MaterialSymbol {
            iconSize: 80
            color: Appearance.colors.colOnPrimaryContainer
            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
            anchors {
                left: parent.left
                bottom: parent.bottom

                leftMargin: 16
                bottomMargin: 20
            }
        }
    }
}
