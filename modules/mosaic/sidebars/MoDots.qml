import QtQuick
import qs.modules.common

// Mosaic OS: the desk's dot field (desk/desktop/shaders/dotfield.frag) behind
// the sidebars in the Mosaic theme. It stands still, so it is drawn when the
// sidebar opens and never again; shuffle() moves the waves somewhere new (each
// time the sidebar opens).
ShaderEffect {
    id: dots
    property real time: Math.random() * 100
    function shuffle(): void { dots.time = Math.random() * 100; }
    property vector2d size: Qt.vector2d(width, height)
    property vector2d pointer: Qt.vector2d(-1000, -1000) // no lens: it would repaint on every move
    property real pitch: 15
    property real alpha: 0.24
    property color tone0: Appearance.m3colors.m3primary
    property color tone1: Appearance.m3colors.m3secondary
    property color tone2: Appearance.m3colors.m3tertiary
    fragmentShader: Qt.resolvedUrl("../../../desk/desktop/shaders/dotfield.frag.qsb")
}
