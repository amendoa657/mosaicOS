import QtQuick
import qs.modules.common

// Mosaic OS: mosaic-ui's key (.mo-tecla, mosaicStore mosaic-ui/mosaic.css), for
// the sidebars in the Mosaic theme. A flat face over a darker body of the same
// colour; while `down` the face sinks by `depth` onto it. `on` paints the face
// in the primary colour (a toggle that is on). Children go on the face, so they
// sink with it; `ink` is the colour to draw them in.
Item {
    id: k
    property bool on: false
    property bool down: false
    property bool hovered: false
    property real depth: 4
    property real radius: 10
    property color face: k.on ? Appearance.m3colors.m3primary
        : k.hovered ? Appearance.m3colors.m3surfaceContainerHighest : Appearance.m3colors.m3surfaceContainerHigh
    readonly property color ink: k.on ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurface
    default property alias content: faceRect.data

    // the body: what the face sinks onto
    Rectangle {
        y: k.depth
        width: k.width
        height: k.height - k.depth
        radius: k.radius
        color: Qt.darker(k.face, k.on ? 1.55 : 1.8)
    }
    Rectangle {
        id: faceRect
        y: k.down ? k.depth : 0
        width: k.width
        height: k.height - k.depth
        radius: k.radius
        color: k.face
        Behavior on y { NumberAnimation { duration: 60 } }
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
