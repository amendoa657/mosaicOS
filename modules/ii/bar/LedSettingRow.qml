import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Linha "ícone + texto + interruptor" do menu da fita LED
RowLayout {
    id: root
    required property string icon
    required property string label
    required property bool checked
    signal toggled(bool value)
    Layout.fillWidth: true
    spacing: 8
    MaterialSymbol {
        text: root.icon
        iconSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colOnLayer2
    }
    StyledText {
        Layout.fillWidth: true
        text: root.label
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnLayer1
    }
    StyledSwitch {
        checked: root.checked
        onClicked: root.toggled(checked)
    }
}
