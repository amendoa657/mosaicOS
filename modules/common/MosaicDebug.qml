pragma Singleton
import QtQuick
import Quickshell

// Mosaic OS: switches to turn pieces of the shell off one by one, to see which
// one weighs on the GPU (the "Desliga-tudo" panel, modules/mosaic/debug,
// Super+Alt+G). Each switch is a PanelLoader's extraCondition in
// panelFamilies/IllogicalImpulseFamily.qml, except `pontos`, which the desk's
// dot field reads. Not saved: a restart turns everything back on.
Singleton {
    property bool papel: true    // the wallpaper (ii Background)
    property bool pontos: true   // the desk's dot field
    property bool widgets: true  // the whole desk
    property bool ilha: true
    property bool dock: true
    property bool barra: true    // the top band
    property bool ladoEsq: true  // the left sidebar
    property bool ladoDir: true  // the right sidebar
    property bool cantos: true   // the screen's rounded corners
    property bool stage: true
}
