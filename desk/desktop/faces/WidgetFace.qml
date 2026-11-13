// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   I   D   G   E   T       F   A   C   E                              │
// │   the grid every family is laid out on                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The layout every Modern face shares: the mark top left, the label top right,
// the main reading along the bottom with a caption under it. Keeping this fixed
// lets widgets line up as a set. Wide faces give part of their width to `extra`
// (a sparkline, the forecast, the transport); large ones add `body` in the
// middle.
Item {
    id: root

    // The module's name in the corner, so widgets identify themselves without a
    // hover.
    property string label: ""

    // The main value, as large as the face allows.
    property string reading: ""

    // Qualifies the reading: time remaining, location, the timer's label. One
    // line, elided.
    property string note: ""

    // Colours resolved by the widget from its ink and style.
    property var ink: DesktopService.inkFor(null)

    // Warning colours do not follow the palette; modules pass one in when their
    // reading needs it.
    property color tint: root.ink.text

    // The caption's colour, for a caption that is itself the warning (a
    // price's rise or fall).
    property color noteTint: root.ink.muted

    // The reading's size: the same for every family except the band, which has
    // height to spare.
    property int readingSize: Theme.fontSizeWidget

    // The fraction of the width given to `extra`; 0 for a square. Declared
    // rather than derived from `extra`'s contents, because bindings do not
    // track list properties.
    property real extraShare: 0

    // The mark, sized up to the box.
    default property alias mark: markBox.data

    // Wide-face content.
    property alias extra: extraBox.data

    // Large-face content, between the mark and the reading.
    property alias body: bodyBox.data

    // Wide faces get more padding so they do not look like a stretched square.
    readonly property int padding: root.width > 300 ? 22 : 18

    readonly property real textWidth:
        root.width - 2 * root.padding - root.width * root.extraShare

    // Mosaic OS: the module this face belongs to, found up the tree (the face
    // registries carry `moduleId`), for the pixel symbol and the tone
    property string moduleId: ""
    Component.onCompleted: {
        for (let p = root.parent; p && root.moduleId === ""; p = p.parent)
            if (p.moduleId !== undefined && p.moduleId !== "")
                root.moduleId = p.moduleId
    }
    readonly property bool mosaicLook: Theme.look === "mosaic"
    readonly property bool appleLook: Theme.look === "apple"
    readonly property color tone: Theme.toneOf(root.moduleId)
    readonly property var symbols: ({
        clock: "relogio", calendar: "calendario", weather: "nuvem", media: "play", photo: "imagem",
        anniversary: "coracao", notes: "editar", tasks: "check", timer: "ampulheta", screentime: "ampulheta",
        stats: "chip", volume: "volume", network: "wifi", bluetooth: "bluetooth", updates: "pacote",
        claude: "faisca", github: "git", spectrum: "barras", lyrics: "microfone", notifications: "sino"
    })

    // Mosaic: the mark is a mosaic-ui pixel symbol in the module's tone
    PixelSymbol {
        visible: root.mosaicLook
        x: root.padding
        y: root.padding
        width: 27
        height: 27
        name: root.symbols[root.moduleId] ?? "mosaico"
        color: root.tone
    }

    Item {
        id: markBox
        visible: !root.mosaicLook

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.topMargin: root.padding
        width: 40
        height: 40
    }

    Text {
        id: name

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding + 4
        anchors.left: markBox.right
        anchors.leftMargin: 8

        // Mosaic: the mono voice (10 px, 600, capitals, spaced); macOS: bold, in the tone
        text: root.mosaicLook ? root.label.toUpperCase() : root.label
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.family: root.mosaicLook ? Theme.fontMonoUi : Theme.fontFamily
        font.pixelSize: root.mosaicLook ? 10 : root.appleLook ? Theme.fontSizeRegular : Theme.fontSizeSmall
        font.weight: root.mosaicLook ? Font.DemiBold : root.appleLook ? Font.Bold : Font.DemiBold
        font.letterSpacing: root.mosaicLook ? 1.5 : 0
        color: root.appleLook ? root.tone : root.ink.muted
    }

    Item {
        id: bodyBox

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: markBox.bottom
        anchors.bottom: readings.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: 12
        anchors.bottomMargin: 12
    }

    // Anchored to the bottom, so the reading stays put with or without a
    // caption.
    Column {
        id: readings

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.bottomMargin: root.padding
        width: root.textWidth
        spacing: 2

        // Readings range from two characters to "Desconectado", so the text
        // shrinks to fit on one line, down to `fontSizeLarge`. `HorizontalFit`,
        // not `Fit`: this item is as tall as its text, so `Fit` has no height
        // to shrink towards.
        Text {
            width: parent.width
            text: root.reading
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeLarge
            // Mosaic: the big number (700, tight); macOS: SF-like display type
            font.family: root.appleLook ? Theme.fontDisplay : Theme.fontFamily
            font.pixelSize: root.mosaicLook ? Math.round(root.readingSize * 1.08) : root.readingSize
            font.weight: root.mosaicLook ? Font.Bold : Font.DemiBold
            font.letterSpacing: root.mosaicLook ? -root.readingSize * 0.03 : 0
            color: root.tint
        }

        Text {
            width: parent.width
            visible: root.note !== ""
            text: root.note
            elide: Text.ElideRight
            font.family: root.mosaicLook ? Theme.fontMonoUi : Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: root.noteTint
        }
    }

    // Under the label rather than beside the mark, so the label has the top
    // right corner to itself.
    Item {
        id: extraBox

        anchors.right: parent.right
        anchors.top: name.bottom
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.padding
        anchors.topMargin: 10
        anchors.bottomMargin: root.padding
        width: Math.max(0, root.width * root.extraShare - root.padding)
    }
}
