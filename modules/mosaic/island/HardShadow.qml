import QtQuick
import qs.modules.common

// The neo-brutalist hard shadow (brutal themes, like Gruvbox): a flat copy of
// the parent shape, moved down-right by MosaicTheme.shadow px, no blur. Put it
// inside any Rectangle: a child with z -1 is drawn BEHIND its parent.
// `sink` (pressed): the parent moves into its shadow, so the button looks pushed
// in; the parent does the moving (see `sinkShift`), the shadow stays put.
Rectangle {
    property bool sink: false
    readonly property real sinkShift: MosaicTheme.brutal && sink ? MosaicTheme.shadow * 0.75 : 0
    visible: MosaicTheme.brutal
    z: -1
    x: MosaicTheme.shadow - sinkShift
    y: MosaicTheme.shadow - sinkShift
    width: parent.width
    height: parent.height
    radius: parent.radius
    color: MosaicTheme.shadowColor
}
