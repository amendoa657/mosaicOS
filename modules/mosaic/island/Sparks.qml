import QtQuick
import qs.modules.common

// A burst of sparks flying out from one point and fading (charging started,
// phone connected). Each spark has its own angle and reach, a little shuffled
// so it doesn't look like a perfect star. Plays once when it appears.
// Ported from hyprdots' IslandBurst (fedyaqq34356/hyprdots, GPL-3.0).
Item {
    id: burst
    property color tint: "white"
    property int count: 12
    property real reach: 38
    property int delay: 140
    property int duration: 760
    width: 0
    height: 0

    function play() {
        for (let i = 0; i < sparks.count; i++)
            sparks.itemAt(i)?.fly();
    }
    Component.onCompleted: play()

    Repeater {
        id: sparks
        model: burst.count
        delegate: Rectangle {
            id: spark
            required property int index
            readonly property real ang: index / burst.count * Math.PI * 2 + ((index * 7) % 5) * 0.09
            readonly property real far: burst.reach * (0.7 + 0.3 * (((index * 37) % 10) / 10))
            property real d: 0
            width: index % 3 === 0 ? 4.5 : 3
            height: width
            radius: MosaicTheme.r(width / 2)
            color: index % 2 ? burst.tint : Qt.lighter(burst.tint, 1.55)
            x: Math.cos(ang) * d - width / 2
            y: Math.sin(ang) * d - height / 2
            opacity: 0
            function fly() { run.restart(); }
            SequentialAnimation {
                id: run
                PauseAnimation { duration: burst.delay + (spark.index % 4) * 18 }
                ParallelAnimation {
                    NumberAnimation { target: spark; property: "d"; from: burst.reach * 0.35; to: spark.far; duration: burst.duration; easing.type: Easing.OutCubic }
                    NumberAnimation { target: spark; property: "scale"; from: 1.3; to: 0.3; duration: burst.duration; easing.type: Easing.InQuad }
                    SequentialAnimation {
                        NumberAnimation { target: spark; property: "opacity"; from: 0; to: 1; duration: 90 }
                        NumberAnimation { target: spark; property: "opacity"; to: 0; duration: burst.duration - 90; easing.type: Easing.InCubic }
                    }
                }
            }
        }
    }
}
