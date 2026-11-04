import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Aba que abre e fecha no rodapé do menu da fita LED (Animações, Opções)
ColumnLayout {
    id: root
    required property string icon
    required property string title
    property string summary: "" // o que está ativo, mostrado com a aba fechada
    property bool expanded: false
    default property alias content: body.data
    Layout.fillWidth: true
    spacing: 8

    RippleButton {
        Layout.fillWidth: true
        implicitHeight: 40
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer2
        onClicked: root.expanded = !root.expanded
        contentItem: RowLayout {
            spacing: 8
            MaterialSymbol {
                Layout.leftMargin: 8
                text: root.icon
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: root.summary
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            MaterialSymbol {
                Layout.rightMargin: 6
                text: "expand_more"
                rotation: root.expanded ? 180 : 0
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 10
        visible: root.expanded
    }
}
