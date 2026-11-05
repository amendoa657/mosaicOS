import QtQuick

// A real spring that follows `target`, with its speed exposed (`velocity`), so
// the island can wobble like jelly while it moves. Same model as SwiftUI's
// springs: `response` is roughly how many seconds one swing takes, `damping`
// how quickly it calms down (1 = no overshoot, lower = bouncier).
// Ported from hyprdots' MorphSpring (fedyaqq34356/hyprdots, GPL-3.0).
//
// The math, each frame: acceleration = -w²·(value - target) - 2·z·w·velocity,
// where w = 2π / response and z = damping. The frame is cut into 4 ms steps
// so a slow frame can't make the spring blow up.
Item {
    id: sp
    visible: false

    property real target: 0
    property real value: 0
    property real velocity: 0

    property real response: 0.46
    property real damping: 0.86
    property real epsilon: 0.0005
    // going down (closing) is a quick eased slide instead of a bounce, unless springBack
    property bool springBack: true
    property int closeMs: 300

    readonly property bool running: tick.running
    property bool closing: false
    property real closeFrom: 0
    property real closeStart: 0

    onTargetChanged: kick()

    // jump straight to v, no animation (it never touches `target`, so a binding
    // on target keeps working afterwards)
    function settle(v) {
        tick.running = false;
        sp.closing = false;
        sp.velocity = 0;
        sp.value = v;
    }

    function kick() {
        sp.closing = sp.target < sp.value && !sp.springBack;
        if (sp.closing) {
            sp.closeFrom = sp.value;
            sp.closeStart = Date.now();
            sp.velocity = 0;
        }
        tick.running = true;
    }

    FrameAnimation {
        id: tick
        onTriggered: {
            if (sp.closing) {
                const k = Math.min(1, (Date.now() - sp.closeStart) / Math.max(1, sp.closeMs));
                const e = 1 - Math.pow(1 - k, 3); // ease out cubic
                sp.value = sp.closeFrom + (sp.target - sp.closeFrom) * e;
                if (k >= 1) {
                    sp.value = sp.target;
                    sp.closing = false;
                    running = false;
                }
                return;
            }
            const w = 2 * Math.PI / Math.max(0.05, sp.response);
            const z = sp.damping;
            const dt = Math.min(frameTime, 0.05);
            const steps = Math.max(1, Math.ceil(dt / 0.004));
            const h = dt / steps;
            for (let i = 0; i < steps; i++) {
                const a = -w * w * (sp.value - sp.target) - 2 * z * w * sp.velocity;
                sp.velocity += a * h;
                sp.value += sp.velocity * h;
            }
            // close enough and slow enough: stop (so nothing runs while still)
            if (Math.abs(sp.value - sp.target) < sp.epsilon && Math.abs(sp.velocity) < sp.epsilon * w) {
                sp.value = sp.target;
                sp.velocity = 0;
                running = false;
            }
        }
    }
}
