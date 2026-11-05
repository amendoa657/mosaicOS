#version 440

// The island and the notification bubble as one liquid shape.
//
// Each shape is a signed distance field (SDF): for every pixel, how far it is
// from the shape's edge (negative inside, positive outside). Two fields are
// joined with a "smooth min", which rounds the corner where they meet, so when
// the bubble is close to the island a liquid neck stretches between them.
// Idea and smin from hyprdots' blob.frag (fedyaqq34356/hyprdots, GPL-3.0).
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o goo.frag.qsb goo.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // effect size in pixels
    vec4 island;      // cx, cy, half width, half height (px)
    vec4 twin;        // a short strip under the island's middle: where the neck grows from
    vec4 body;        // the bubble
    float islandRadius;
    float bodyRadius;
    float fuse;       // how far apart the shapes still melt together
    float islandLeft; // the island's colour wash runs from its left edge...
    float islandWidth;// ...across its width
    vec4 stop0;       // the wash: left, middle and right colours (opaque)
    vec4 stop1;
    vec4 stop2;
    float fillAlpha;
    vec4 strokeColor;
    float strokeAlpha;
};

float sdRoundBox(vec2 p, vec4 r, float rad) {
    rad = min(rad, min(r.z, r.w));
    vec2 d = abs(p - r.xy) - r.zw + vec2(rad);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - rad;
}

// circular smooth min: only bends where both shapes are closer than k
float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * size;

    float dI = sdRoundBox(p, island, islandRadius);
    float dT = sdRoundBox(p, twin, 4.0);
    float dB = sdRoundBox(p, body, bodyRadius);
    float d = smin(dI, smin(dT, dB, max(fuse, 0.001)), 10.0);

    // one pixel of anti-aliasing at any scale (an SDF changes 1 per pixel)
    float aa = max(fwidth(d), 0.0001);
    float inside = 1.0 - smoothstep(-aa, aa, d);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float t = clamp((p.x - islandLeft) / max(islandWidth, 1.0), 0.0, 1.0);
    vec3 rgb = t < 0.5 ? mix(stop0.rgb, stop1.rgb, t * 2.0) : mix(stop1.rgb, stop2.rgb, (t - 0.5) * 2.0);
    float alpha = fillAlpha;

    // the outline follows the whole silhouette, neck included
    float band = smoothstep(-1.0 - aa, -1.0 + aa, d);
    rgb = mix(rgb, strokeColor.rgb, band * strokeAlpha);
    alpha = mix(alpha, max(alpha, strokeAlpha), band);

    alpha *= inside * qt_Opacity;
    fragColor = vec4(rgb * alpha, alpha);
}
