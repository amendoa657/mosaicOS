import QtQuick
import qs.modules.common

// The Mosaic mark, alive: the four blocks of the Mosaic OS logo (a big square,
// a tall bar, a wide bar and a small square, on an 88-unit grid with 8 of gap)
// in the theme tones, with one face (a pair of eyes in the middle). It only moves on events: blinks now and then, dances
// while music plays, jumps on a notification, thinks (blocks turn) while the AI
// answers, and gets dizzy if poked too much.
Item {
    id: root
    property real size: 22
    // What is going on: "idle" | "dance" | "think" (set from outside)
    property string baseMood: "idle"
    property bool dizzy: false
    property bool showFace: true
    readonly property string mood: dizzy ? "dizzy" : baseMood
    // the logo on an 88-unit grid: 56 + 8 + 24. Each slot is [x, y, w, h] in units
    readonly property real unit: size / 88
    readonly property var slots: [[0, 0, 56, 56], [64, 0, 24, 56], [0, 64, 56, 24], [64, 64, 24, 24]]
    readonly property var tones: [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colOnLayer0]

    implicitWidth: size
    implicitHeight: size


    // One hop with an elastic landing (notification)
    function jump() {
        hop.restart();
    }

    // ---------- body ----------
    Item {
        id: body
        width: root.size
        height: root.size
        transformOrigin: Item.Bottom

        SequentialAnimation {
            id: hop
            NumberAnimation { target: body; property: "y"; to: -root.size * 0.45; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBounce }
        }

        Repeater {
            model: 4
            delegate: Rectangle {
                id: blockRect
                required property int index
                // think: the blocks travel one place clockwise, again and again,
                // taking the size of the place they land on
                property int turn: 0
                readonly property int slot: root.mood === "think" ? [0, 1, 3, 2][(([0, 1, 3, 2].indexOf(index)) + turn) % 4] : index
                readonly property var g: root.slots[slot]
                x: g[0] * root.unit
                y: g[1] * root.unit + danceOffset
                width: g[2] * root.unit
                height: g[3] * root.unit
                radius: MosaicTheme.r(Math.max(1.5, root.size * 0.05))
                color: root.tones[index]
                property real danceOffset: 0
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 300 } }

                // dance: blocks bob in turns, like a little equalizer
                SequentialAnimation on danceOffset {
                    running: root.mood === "dance"
                    loops: Animation.Infinite
                    PauseAnimation { duration: (blockRect.index % 2) * 140 + Math.floor(blockRect.index / 2) * 70 }
                    NumberAnimation { to: -root.size * 0.14; duration: 140; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0; duration: 220; easing.type: Easing.OutBack }
                    onStopped: blockRect.danceOffset = 0
                }
                Timer {
                    running: root.mood === "think"
                    repeat: true
                    interval: 380
                    onTriggered: blockRect.turn++
                }
            }
        }

        // dizzy: the whole mark wobbles
        SequentialAnimation on rotation {
            running: root.mood === "dizzy"
            loops: 3
            NumberAnimation { to: 14; duration: 90 }
            NumberAnimation { to: -14; duration: 180 }
            NumberAnimation { to: 0; duration: 90 }
            onStopped: body.rotation = 0
        }

        // ---------- face ----------
        Row {
            id: eyes
            visible: root.showFace
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.size * 0.02
            spacing: root.size * 0.08
            Repeater {
                model: 2
                delegate: Rectangle {
                    width: root.size * 0.26
                    height: root.size * 0.34 * eyelid.open
                    radius: MosaicTheme.r(width / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "white"
                    border.width: Math.max(1, root.size * 0.03)
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    Rectangle { // pupil
                        visible: eyelid.open > 0.4
                        width: parent.width * 0.55
                        height: width
                        radius: MosaicTheme.r(width / 2)
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.mood === "dizzy" ? Math.sin(dizzySpin.angle) * parent.width * 0.2 : 0
                        anchors.verticalCenterOffset: root.mood === "dizzy" ? Math.cos(dizzySpin.angle) * parent.width * 0.2 : 0
                        color: "#1b1b1f"
                    }
                }
            }
        }
    }

    // Eyelid: 1 open, 0 closed. Blinks every few seconds (one short animation, no loop running in between)
    QtObject {
        id: eyelid
        property real open: 1
    }
    SequentialAnimation {
        id: blink
        NumberAnimation { target: eyelid; property: "open"; to: 0.1; duration: 70 }
        NumberAnimation { target: eyelid; property: "open"; to: 1; duration: 110 }
    }
    Timer {
        running: root.visible
        repeat: true
        interval: 3500 + Math.random() * 3500
        onTriggered: {
            blink.restart();
            interval = 3500 + Math.random() * 3500;
        }
    }

    QtObject {
        id: dizzySpin
        property real angle: 0
    }
    NumberAnimation {
        running: root.mood === "dizzy"
        loops: Animation.Infinite
        target: dizzySpin
        property: "angle"
        from: 0
        to: Math.PI * 2
        duration: 500
    }

    // Poke it (click): five quick pokes and it gets dizzy for a moment
    property int pokes: 0
    Timer {
        id: pokeWindow
        interval: 1200
        onTriggered: root.pokes = 0
    }
    Timer {
        id: dizzyTimer
        interval: 1800
        onTriggered: root.dizzy = false
    }
    function poke() {
        root.pokes++;
        pokeWindow.restart();
        root.jump();
        if (root.pokes >= 5 && !root.dizzy) {
            root.dizzy = true;
            root.pokes = 0;
            dizzyTimer.restart();
        }
    }
}
