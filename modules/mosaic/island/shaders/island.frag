#version 440

// The island's surface, floating: a dark pill at rest, a rounded card as the
// panel, and a dome as the compass (rounded top, half oval bottom).
//
// The shape is the intersection of two rounded boxes (SDF: max of the two):
// one carries the top corners (rTop) and runs far below, the other carries the
// bottom corners (rBot) and runs far above. Each keeps its own radius, so the
// bottom can be a half circle (rBot = width / 2) while the top stays a small
// curve. Then the whole thing is squashed vertically: the shape is built
// `hu` pixels tall and drawn `size.y` tall, which turns the half circle into a
// half oval.
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o island.frag.qsb island.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;     // drawn size (px)
    float rTop;    // top corners
    float rBot;    // bottom corners (width / 2 = half circle)
    float hu;      // height the shape is built at, before the squash
    vec4 stop0;    // colour wash: left, middle, right (opaque)
    vec4 stop1;
    vec4 stop2;
    float fillAlpha;
    vec4 strokeColor;
    float strokeAlpha;
};

float sdBox(vec2 p, vec2 c, vec2 b, float r) {
    r = min(r, min(b.x, b.y));
    vec2 d = abs(p - c) - b + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float sq = size.y / max(hu, 1.0);      // the squash (1 = none)
    vec2 q = vec2(p.x, p.y / max(sq, 0.001)); // back into the unsquashed shape
    float w = size.x;
    float big = 4096.0;

    // top box: from 0 down past the bottom; bottom box: from far above down to hu
    float dTop = sdBox(q, vec2(w * 0.5, (big) * 0.5), vec2(w * 0.5, big * 0.5), rTop);
    float dBot = sdBox(q, vec2(w * 0.5, hu - big * 0.5), vec2(w * 0.5, big * 0.5), rBot);
    float d = max(dTop, dBot) * min(1.0, sq);

    float aa = max(fwidth(d), 0.0001);
    float inside = 1.0 - smoothstep(-aa, aa, d);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float t = clamp(p.x / max(w, 1.0), 0.0, 1.0);
    vec3 rgb = t < 0.5 ? mix(stop0.rgb, stop1.rgb, t * 2.0) : mix(stop1.rgb, stop2.rgb, (t - 0.5) * 2.0);
    float alpha = fillAlpha;

    float band = smoothstep(-1.0 - aa, -1.0 + aa, d);
    rgb = mix(rgb, strokeColor.rgb, band * strokeAlpha);
    alpha = mix(alpha, max(alpha, strokeAlpha), band);

    alpha *= inside * qt_Opacity;
    fragColor = vec4(rgb * alpha, alpha);
}
