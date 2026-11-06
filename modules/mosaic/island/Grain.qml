import QtQuick
import qs.modules.common

// Film grain laid over a rounded surface (retro themes, like Horizonte): put it
// inside the surface and it fills it. Off (not even created as a shader pass)
// when the theme has no grain.
ShaderEffect {
    property real radius: 0
    property real amount: MosaicTheme.shellGrain
    anchors.fill: parent
    visible: amount > 0
    fragmentShader: Qt.resolvedUrl("shaders/grain.frag.qsb")
    property vector2d size: Qt.vector2d(width, height)
}
