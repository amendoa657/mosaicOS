import QtQuick
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A battery that fills with water. Charging, the water sloshes faster, bubbles
// rise through it, a gleam sweeps across and the bolt pulses; low, it breathes.
// Ported from hyprdots' IslandBattery (fedyaqq34356/hyprdots, GPL-3.0); the water
// is a Canvas here (its edge is a sine wave), drawn only while it is visible.
Item {
    id: bat
    property real value: 0.5   // 0..1
    property bool charging: false
    property color tint: Appearance.colors.colPrimary
    property real lowAt: 0.2
    readonly property bool low: !charging && value <= lowAt
    readonly property color ink: low ? Appearance.colors.colError : tint

    implicitWidth: 60
    implicitHeight: 28

    // the level climbs to the value when it appears (1.2 s, easing out)
    property real shown: 0
    Component.onCompleted: shown = Math.max(0, Math.min(1, value))
    onValueChanged: shown = Math.max(0, Math.min(1, value))
    Behavior on shown { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }

    property real phase: 0
    FrameAnimation {
        running: bat.visible
        onTriggered: {
            bat.phase += frameTime * (bat.charging ? 5.7 : 1.8);
            water.requestPaint();
        }
    }

    readonly property real cap: Math.max(3, height * 0.1)
    readonly property real bodyW: width - cap - 2

    Rectangle { // the shell
        id: shell
        width: bat.bodyW
        height: bat.height
        radius: bat.height * 0.3
        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.94)
        border.width: 1.6
        border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.68)
    }
    Rectangle { // the cap
        x: bat.bodyW + 1.5
        anchors.verticalCenter: shell.verticalCenter
        width: bat.cap
        height: bat.height * 0.36
        radius: width / 2
        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.68)
    }

    ClippingRectangle {
        id: well
        x: 3.5
        y: 3.5
        width: shell.width - 7
        height: shell.height - 7
        radius: shell.radius - 3
        color: "transparent"

        // the water: filled from the left, its right edge a moving sine wave
        Canvas {
            id: water
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                const level = w * bat.shown;
                if (level < 0.5)
                    return;
                const amp = bat.charging ? 2.2 : 1.0;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                for (let y = 0; y <= h; y += 2)
                    ctx.lineTo(level + Math.sin(bat.phase + y / h * Math.PI * 2) * amp, y);
                ctx.lineTo(0, h);
                ctx.closePath();
                const g = ctx.createLinearGradient(0, 0, 0, h);
                g.addColorStop(0, Qt.lighter(bat.ink, 1.3));
                g.addColorStop(1, Qt.darker(bat.ink, 1.35));
                ctx.fillStyle = g;
                ctx.fill();
            }
        }

        // charging: little bubbles rise through the water, one after another
        Repeater {
            model: bat.charging ? 5 : 0
            delegate: Rectangle {
                id: bub
                required property int index
                width: 2.5 + (index % 2)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.55)
                x: Math.min(well.width * bat.shown - 4, well.width * bat.shown * (index + 0.5) / 5)
                y: well.height
                visible: bat.shown > 0.08
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    PauseAnimation { duration: bub.index * 230 }
                    NumberAnimation { from: well.height; to: -4; duration: 900 + bub.index * 90; easing.type: Easing.InQuad }
                }
            }
        }

        // charging: a gleam sweeps across every couple of seconds
        Rectangle {
            id: glint
            visible: bat.charging
            width: well.width * 0.35
            height: well.height * 3
            anchors.verticalCenter: parent.verticalCenter
            rotation: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.32) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on x {
                running: bat.charging
                loops: Animation.Infinite
                NumberAnimation { from: -glint.width; to: well.width + glint.width; duration: 1300; easing.type: Easing.InOutCubic }
                PauseAnimation { duration: 900 }
            }
        }
    }

    MaterialSymbol { // the bolt, pulsing while it charges
        anchors.centerIn: shell
        visible: bat.charging
        text: "bolt"
        fill: 1
        iconSize: Math.round(bat.height * 0.62)
        color: "white"
        SequentialAnimation on scale {
            running: bat.charging
            loops: Animation.Infinite
            NumberAnimation { to: 1.18; duration: 520; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 680; easing.type: Easing.InOutSine }
        }
    }

    // low: it breathes
    SequentialAnimation on opacity {
        running: bat.low
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.55; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
    }
}
