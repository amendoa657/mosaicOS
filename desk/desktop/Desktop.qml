// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D   E   S   K   T   O   P                                              │
// │   the layer under the windows · widgets on the wallpaper                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

import "../theme"
import qs.modules.common
import "../services"
import "../components"

// The layer between the wallpaper and the windows: no exclusive zone, and on
// the bottom layer so any window covers it.
//
// ── ARRANGING ───────────────────────────────────────────────────────────────
//
// Arranging raises the surface to the top layer and takes the whole screen for
// input, so widgets can be moved even with windows open. A card holds every
// module; drag a widget to move it, pull its corner to resize it, click it
// for its inspector.
//
// Arranging holds the keyboard, on demand and under a focus grab as the bar
// holds it, and ends with Escape, a right-click or a click on any other
// surface. The right-click menu is a surface of its own, so opening it never
// raises the widgets.
PanelWindow {
    id: root
    CornerGuard {}

    readonly property bool editing: DesktopService.editing

    // Every board is one screen's, and nothing on it ever leaves: widgets,
    // decks and the grid are this screen's alone. The mode is held by the
    // screen it was entered from, the card is on the screen the pointer is
    // on, and the inspector and the picker are beside the widget they are
    // about, whichever screen that is on.
    readonly property string screenName: root.screen?.name ?? ""
    readonly property bool hosting: DesktopService.editingScreen === root.screenName

    // The card follows the pointer while arranging: crossing to another board
    // brings it there and takes it off this one. The desk is on `top` and
    // covers the screen for as long as the mode lasts, so this is hovered
    // wherever the pointer goes on it.
    HoverHandler {
        id: pointerOn
    }

    // Nothing in hand: the pointer runs past the seam while something is
    // being dragged, and the card changing screens under it would take the
    // drag with it.
    readonly property bool claims: root.editing && pointerOn.hovered
        && !DesktopService.inHand && DeckService.dragging === ""

    onClaimsChanged: if (root.claims) DesktopService.galleryScreen = root.screenName

    function about(key: string): bool {
        return key !== ""
            && DesktopService.nameOf(DesktopService.entryOf(key)) === root.screenName
    }


    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Namespace for layer rules, e.g. `layerrule = blur, impasto-desktop`. Not
    // set by default.
    WlrLayershell.namespace: "mosaic-desk"
    // The widgets take the island's glass (`Theme.surfaceIn`).
    readonly property bool glassy: true
    readonly property string groundStyle: Theme.deskStyle

    // Raised above the windows while arranging, and only then. Mosaic OS: a
    // moment after the backdrop maps (`deskUp`), so the desk joins the top layer
    // after it and sits above it; the backdrop only exists while arranging.
    WlrLayershell.layer: root.deskUp ? WlrLayer.Top : WlrLayer.Bottom
    property bool deskUp: false
    Timer { id: deskUpLater; interval: 60; onTriggered: root.deskUp = root.editing }

    // While arranging. The grab keeps the keyboard here while the pointer is
    // elsewhere, and a click on any surface but this one and the edges' clears
    // it, which ends the mode; the compositor hands the keyboard back.
    WlrLayershell.keyboardFocus: root.editing && root.hosting
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.editing && root.hosting
        // Defensive: both lists are read while the singletons are still
        // being built, and one of them is briefly undefined.
        windows: (DesktopService.windows ?? []).concat(DeckService.windows ?? [])
        onCleared: DesktopService.edit(false)
    }

    Component.onCompleted: DesktopService.publish(root.screenName, root)
    Component.onDestruction: DesktopService.publish(root.screenName, null)

    // Whether the desk has been drawn on `top` since arranging began. The
    // backdrop waits for it: shown before, it covers the widgets for as long
    // as the desk takes to draw the card.
    property bool raised: false
    property bool synced: false

    onEditingChanged: {
        root.raised = false
        root.synced = false
        if (root.editing)
            deskUpLater.restart()
        else
            root.deskUp = false
    }
    onDeskUpChanged: {
        root.raised = false
        root.synced = false
    }

    // A frame synchronised after the change carries the new layer; one
    // already rendering when it happened does not.
    Connections {
        target: root.deskUp && !root.raised ? surface.Window.window : null

        function onAfterSynchronizing(): void {
            root.synced = true
        }

        function onFrameSwapped(): void {
            if (root.synced)
                root.raised = true
        }
    }

    // The whole screen, ignoring exclusive zones, so a widget dragged into the
    // bar's area stays on this surface; the compositor sends away a pointer
    // that leaves its surface, and the drag would drop. The board inside is
    // inset by what the bar and the dock keep clear (`DesktopService.insets`).
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    readonly property var menu: DesktopService.menu

    // ── INPUT MASK ──────────────────────────────────────────────────────────
    //
    // The whole screen: a right-click anywhere opens the desktop menu. A left
    // click on the background only closes a menu.
    mask: Region {
        width: root.width
        height: root.height
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    // Not `id: board`: the widgets take a `board` property, and an id with the
    // same name as a property in scope resolves to the property, handing each
    // widget itself. A scope, so Escape reaches it and a caption field inside
    // keeps its own.
    FocusScope {
        id: surface

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: DesktopService.edit(false)
        anchors.topMargin: DesktopService.insets.top
        anchors.leftMargin: DesktopService.insets.left
        anchors.rightMargin: DesktopService.insets.right
        anchors.bottomMargin: DesktopService.insets.bottom

        // The grid's available area, published because the service works in
        // cells and placing from the tray needs the same answer. One entry
        // per screen: the grid is worked out from the board's own sides.
        onWidthChanged: DesktopService.setBoard(root.screenName, surface.width, surface.height)
        onHeightChanged: DesktopService.setBoard(root.screenName, surface.width, surface.height)
        Component.onCompleted: DesktopService.setBoard(root.screenName, surface.width, surface.height)

        // Mosaic OS, the Mosaic theme: mosaic-ui's dot field (shaders/dotfield.frag),
        // dots in the three theme colours under the widgets. It stands still: no
        // frames at all, because every frame of this layer makes Hyprland redo the
        // blur behind the translucent windows. Each left click on the background
        // moves it on: the waves slide to a new place in 0.6 s and stop again.
        ShaderEffect {
            id: dotField
            readonly property bool on: Theme.look === "mosaic" && (Config.options?.mosaicWidgets?.pixelField ?? true)
                && !root.editing && !DesktopService.desktopHidden && MosaicDebug.pontos
            anchors.fill: parent
            anchors.topMargin: -DesktopService.insets.top
            anchors.bottomMargin: -DesktopService.insets.bottom
            visible: on
            property vector2d size: Qt.vector2d(width, height)
            property vector2d pointer: Qt.vector2d(-1000, -1000) // the lens is off: it repainted on every move
            property real time: Math.random() * 60 // a different field each start
            property real pitch: 15
            property real alpha: 0.26
            property color tone0: Appearance.m3colors.m3primary
            property color tone1: Appearance.m3colors.m3secondary
            property color tone2: Appearance.m3colors.m3tertiary
            fragmentShader: Qt.resolvedUrl("shaders/dotfield.frag.qsb")
            // about two radians of every wave: far enough to see the dots move
            function shift(): void {
                if (!dotField.on)
                    return
                fieldSlide.to = dotField.time + 6
                fieldSlide.restart()
            }
            NumberAnimation { id: fieldSlide; target: dotField; property: "time"; duration: 600; easing.type: Easing.OutCubic }
        }

        // Anywhere on the background: leaves arranging, and a left click
        // dismisses the inspector. Declared first, so widget handlers take
        // presses before these. At rest, the right button opens the desktop
        // menu.
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: eventPoint => {
                if (root.editing) {
                    DesktopService.edit(false)
                    return
                }
                const point = surface.mapFromItem(null,
                    eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                DesktopService.openMenu("", root.screenName, point.x, point.y)
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                dotField.shift()
                DesktopService.closeMenu()
                if (root.editing)
                    DesktopService.selected = ""
            }
        }

        // Grid lines, only while arranging; built and destroyed with the mode.
        Loader {
            anchors.fill: parent
            active: root.editing
            sourceComponent: lattice
        }

        // Landing mark: the cell the held item would drop into. Positioned
        // imperatively so it appears in place instead of animating in from
        // wherever it was last hidden; it only animates between cells.
        Rectangle {
            id: landing

            readonly property var spot: DesktopService.landing
                && DesktopService.landing.screen === root.screenName
                ? DesktopService.landing : null
            property bool showing: false

            visible: root.editing && landing.showing
            radius: Theme.desktopRadius
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            border.color: Theme.accent
            border.width: 2

            onSpotChanged: {
                if (!landing.spot) {
                    landing.showing = false
                    return
                }
                const shape = DesktopService.family(landing.spot.family)
                const name = root.screenName
                const x = DesktopService.offsetX(name, landing.spot.col)
                const y = DesktopService.offsetY(name, landing.spot.row)
                slide.enabled = landing.showing
                landing.x = x
                landing.y = y
                landing.width = DesktopService.offsetX(name, landing.spot.col + shape.cols) - Theme.desktopGutter - x
                landing.height = DesktopService.offsetY(name, landing.spot.row + shape.rows) - Theme.desktopGutter - y
                slide.enabled = true
                landing.showing = true
            }

            Behavior on x { id: slide; NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
            Behavior on y { enabled: slide.enabled; NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
            Behavior on width { enabled: slide.enabled; NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
            Behavior on height { enabled: slide.enabled; NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
        }

        // The spectra, under the widgets. Each runs past the board to the
        // screen's own edge.
        Repeater {
            model: ScriptModel {
                values: DesktopService.spectrumKeysOn(root.screenName)
            }

            EdgeSpectrum {
                board: surface
                screenName: root.screenName
                visible: !DesktopService.hidden
            }
        }

        // One widget per key: a Repeater given a new array rebuilds every
        // delegate. The rows change on every drop; the keys only on add and
        // remove.
        // The board with the dock's band given back, which is what the grid
        // is laid out over. The widgets sit in it, so
        // the board moving with the dock moves them not at all instead of
        // sliding them back into place.
        Item {
            id: field

            x: -DesktopService.insets.left
            width: surface.width + DesktopService.insets.left + DesktopService.insets.right
            height: surface.height + DesktopService.insets.bottom
            visible: !DesktopService.hidden

            Repeater {
                model: ScriptModel {
                    values: DesktopService.keysOn(root.screenName)
                }

                Widget {
                    board: surface
                    screenName: root.screenName
                }
            }
        }

        // The card of every module, only while arranging. Above the widgets but
        // below the one being dragged, so a widget dropped onto it is seen
        // arriving. It fills the board and places its card itself.
        Loader {
            anchors.fill: parent
            z: 1
            active: root.editing && DesktopService.galleryScreen === root.screenName
            sourceComponent: Tray { board: surface; screenName: root.screenName }
        }

        // The inspector, beside the selected widget and above everything. It
        // closes when a drag starts.
        Loader {
            anchors.fill: parent
            z: 5
            active: root.editing && DesktopService.picking === ""
                && root.about(DesktopService.selected)
            sourceComponent: Inspector { board: surface }
        }

        // A photo's picker, in the inspector's place while it is open.
        Loader {
            anchors.fill: parent
            z: 5
            active: root.editing && root.about(DesktopService.picking)
            sourceComponent: Picker { board: surface }
        }

    }

    // ── BACKDROP ────────────────────────────────────────────────────────────
    //
    // While arranging, the wallpaper under the grid: the windows on the
    // workspace go out of the way and the desk looks as it does empty. A
    // surface of its own under this one, so the blur rule still has the
    // wallpaper behind the widgets to blur, as at rest; drawn inside this
    // surface, the capsules showed it sharp. On and off at once, never faded:
    // the blur would show the windows through a half-drawn wallpaper.
    // Mosaic OS: mapped only while arranging. Mapped all the time (as in
    // impasto) it was a transparent full-screen surface over the windows that
    // Hyprland composed on every frame; now it maps first and the desk joins
    // the top layer after it (`deskUp`), which keeps it below the desk.
    PanelWindow {
        id: backdropWindow
        CornerGuard {}
        visible: root.editing

        screen: root.screen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WlrLayershell.namespace: "mosaic-desk-backdrop"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"

        // Takes no input, ever.
        mask: Region {}

        // The board's part of the screen, and the bar's band in zen, where
        // no bar covers the windows; the dock keeps its band.
        ClippingRectangle {
            id: backdropClip

            readonly property real band: SettingsService.barHidden ? DesktopService.insets.top : 0
            readonly property real bandTop: DesktopService.insets.top - band

            x: DesktopService.insets.left
            y: bandTop
            width: surface.width
            height: surface.height + band
            color: "transparent"
            visible: root.editing && root.raised && backdrop.status === Image.Ready

            // The whole screen, cropped and centred as the wallpaper daemon
            // draws it, and kept loaded at the screen's own pixels so
            // arranging opens on it.
            Image {
                id: backdrop

                readonly property real ratio:
                    backdropWindow.screen ? backdropWindow.screen.devicePixelRatio : 1

                x: -DesktopService.insets.left
                // By id: a ClippingRectangle holds its children in an inner
                // item, so `parent` is not this rectangle.
                y: -backdropClip.bandTop
                width: backdropWindow.width
                height: backdropWindow.height
                source: WallpaperService.currentWallpaper !== ""
                    ? DesktopService.urlOf(WallpaperService.currentWallpaper) : ""
                sourceSize.width: backdropWindow.width * backdrop.ratio
                sourceSize.height: backdropWindow.height * backdrop.ratio
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    // ── MENU ────────────────────────────────────────────────────────────────
    //
    // Right-click menu. On the background: arrange, new note, wallpaper,
    // palette, settings. On a widget: Edit (opens its inspector), Remove, and
    // Open for a note.
    //
    // A surface of its own on the top layer, so the desk stays under the
    // windows while it is open: raising the desk for it drew every widget over
    // a floating window. It is the whole screen and clear, so a click anywhere
    // else closes it.
    LazyLoader {
        active: root.menu !== null && root.menu.screen === root.screenName && !root.editing

        PanelWindow {
            id: menuWindow
            CornerGuard {}

            readonly property var menu: root.menu
            readonly property var row: menu && menu.key !== "" ? DesktopService.entryOf(menu.key) : null
            readonly property bool onNote: row !== null && row.id === "notes"

            screen: root.screen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            WlrLayershell.namespace: "mosaic-desk-menu"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"

            mask: Region {
                width: menuWindow.width
                height: menuWindow.height
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: DesktopService.closeMenu()
            }

            // At the click, in the board's coordinates, kept on the board.
            PopMenu {
                x: DesktopService.insets.left + (menuWindow.menu
                    ? Math.max(Theme.desktopGutter, Math.min(
                        surface.width - Theme.desktopGutter - width, menuWindow.menu.x))
                    : 0)
                y: DesktopService.insets.top + (menuWindow.menu
                    ? Math.max(Theme.desktopGutter, Math.min(
                        surface.height - Theme.desktopGutter - height, menuWindow.menu.y))
                    : 0)

                rows: {
                    if (!menuWindow.menu)
                        return []
                    if (menuWindow.menu.key === "") {
                        return [
                            { id: "arrange", label: Tr.t("Arrumar widgets"), icon: "󰆾", warn: false },
                            { id: "note", label: Tr.t("Nova nota"), icon: "󰎞", warn: false },
                            { id: "wallpaper", label: Tr.t("Papel de parede"), icon: "󰸉", warn: false },
                            { id: "palette", label: Tr.t("Paleta"), icon: "󰏘", warn: false },
                            { id: "settings", label: Tr.t("Configurações"), icon: "󰒓", warn: false }
                        ]
                    }
                    const rows = []
                    if (menuWindow.onNote)
                        rows.push({ id: "open", label: Tr.t("Abrir"), icon: "󰏫", warn: false })
                    rows.push({ id: "edit", label: Tr.t("Editar"), icon: "󰆾", warn: false })
                    rows.push({ id: "remove", label: Tr.t("Remover"), icon: "󰆴", warn: true })
                    return rows
                }
                onChosen: id => {
                    const menu = menuWindow.menu
                    const row = menuWindow.row
                    DesktopService.closeMenu()
                    switch (id) {
                    case "arrange":
                        DesktopService.edit(true, root.screenName)
                        break
                    case "note":
                        NotesService.create()
                        ModuleService.requestPanel("notes")
                        break
                    case "wallpaper":
                        ModuleService.requestPanel("appearance")
                        break
                    case "palette":
                        ModuleService.requestPanel("palette")
                        break
                    case "settings":
                        DesktopService.settingsRequested()
                        break
                    case "open": {
                        const note = NotesService.noteFor(row)
                        NotesService.open(note ? note.key : "")
                        ModuleService.requestPanel("notes")
                        break
                    }
                    case "edit":
                        DesktopService.edit(true, root.screenName)
                        DesktopService.selected = menu.key
                        break
                    case "remove":
                        DesktopService.remove(menu.key)
                        break
                    }
                }
            }
        }
    }

    Component {
        id: lattice

        Item {
            Repeater {
                model: DesktopService.columnsOn(root.screenName) * DesktopService.rowsOn(root.screenName)

                Rectangle {
                    id: square

                    required property int index
                    readonly property int columns: DesktopService.columnsOn(root.screenName)
                    readonly property int col: square.index % square.columns
                    readonly property int row: Math.floor(square.index / square.columns)

                    x: DesktopService.offsetX(root.screenName, square.col)
                    y: DesktopService.offsetY(root.screenName, square.row)
                    width: DesktopService.offsetX(root.screenName, square.col + 1) - Theme.desktopGutter - square.x
                    height: DesktopService.offsetY(root.screenName, square.row + 1) - Theme.desktopGutter - square.y
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.color: Theme.hairline
                    border.width: 1
                }
            }
        }
    }
}
