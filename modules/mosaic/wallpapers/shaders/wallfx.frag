#version 440
// The wallpaper transition, smooth (no pixels).
//
// With a character (hasMap = 1, a map from scripts/wallfx/wallfx-map.py):
//   1. a thin line draws the character's outline like a pen: every contour
//      starts at its top point and two pens go round to meet at the far side
//      (map B = where a point is along the contour; R outside = how close to it);
//   2. the character fills in, from the outline inwards (map R = depth);
//   3. the rest of the picture spreads out of it with a liquid edge and a
//      glowing rim (map G = the order the outside arrives in), and the line
//      fades away.
// Without one (hasMap = 0): the picture spreads from a few seeds landing one
// after another, with the same liquid edge, rim and glow.
// Only the new picture is drawn (where it has arrived); the old wallpaper is
// simply what is underneath. Edges are anti-aliased with fwidth, so they stay
// one pixel soft at any size.
// Idea from pocket-dots' wallfx (diegoMalagrida/pocket-dots, GPL-3.0).
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o wallfx.frag.qsb wallfx.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source; // the new wallpaper
layout(binding = 2) uniform sampler2D map;    // its outline map (when hasMap)

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // screen size (px)
    vec2 picSize;   // image size (px), to crop it like the wallpaper does
    float progress; // 0..1
    float seed;     // a different layout of seeds every time
    float hasMap;   // 1 = outline mode
    vec4 tone;      // the new wallpaper's vivid colour, for the line and the rim
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
// smooth value noise and a little fbm, for the liquid front
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    return vnoise(p) * 0.6 + vnoise(p * 2.1 + 7.3) * 0.3 + vnoise(p * 4.3 + 1.7) * 0.1;
}

// "cover" crop: the image fills the screen, centred (the map uses the same uv)
vec2 coverUv(vec2 p) {
    float s = max(size.x / picSize.x, size.y / picSize.y);
    return clamp(((p - size * 0.5) / s + picSize * 0.5) / picSize, vec2(0.0), vec2(1.0));
}

// a front at `front` over a field `f`: 1 where it has arrived, soft by one pixel
float arrived(float f, float front) {
    float w = max(fwidth(f), 0.0015);
    return smoothstep(-w, w, front - f);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 uv = coverUv(p);
    vec3 pic = texture(source, uv).rgb;
    vec3 glowTone = mix(tone.rgb, vec3(1.0), 0.35);

    float alpha;
    vec3 col = pic;
    float rim;
    float glow;

    if (hasMap > 0.5) {
        vec4 m = texture(map, uv);
        float inside = smoothstep(0.47, 0.53, m.r);
        float depth = clamp((m.r - 0.5) * 2.0, 0.0, 1.0);
        float tLine = clamp(progress / 0.3, 0.0, 1.0);
        float tFill = clamp((progress - 0.2) / 0.25, 0.0, 1.0);
        float tOut = clamp((progress - 0.4) / 0.6, 0.0, 1.0);

        // 2. fill, inwards
        float fill = inside * arrived(depth, tFill * 1.03);
        // 3. the world, outwards (the front runs a little past 1 so the far corners arrive)
        float front = tOut * 1.12 - 0.04;
        float world = (1.0 - inside) * arrived(m.g, front) * step(0.0001, tOut);
        alpha = max(fill, world);
        float dist = front - m.g;
        rim = (1.0 - inside) * exp(-pow(dist / 0.018, 2.0)) * step(0.0001, tOut) * (1.0 - smoothstep(0.85, 1.0, tOut));
        glow = (1.0 - inside) * exp(-max(-dist, 0.0) / 0.035) * (1.0 - world) * step(0.0001, tOut) * (1.0 - smoothstep(0.8, 1.0, tOut));

        // 1. the line: drawn up to the pen, fading once the world is out
        // the line: its outer half from R outside (0..0.45 next to the outline),
        // its inner half from the depth (the first ~2 px inside)
        float near = max((1.0 - inside) * clamp(m.r / 0.45, 0.0, 1.0),
                         inside * (1.0 - smoothstep(0.0, 2.0 * max(fwidth(depth), 1e-4), depth)));
        float drawn = smoothstep(0.0, 0.02, tLine - m.b);
        float line = near * near * drawn * (1.0 - smoothstep(0.1, 0.6, tOut));
        col = mix(col, glowTone, rim * 0.7);
        col = mix(col, glowTone, line);
        float lineAlpha = line;
        // the line glows a touch while it is being drawn, then the fill takes over
        alpha = max(alpha, lineAlpha);
        // a soft light just outside the moving front
        vec4 outer = vec4(tone.rgb * 0.5 * glow, 0.4 * glow);
        if (progress >= 0.995) {
            alpha = 1.0;
            col = pic;
            outer = vec4(0.0);
        }
        vec4 face = vec4(col * alpha, alpha);
        fragColor = (face + outer * (1.0 - alpha)) * qt_Opacity;
        return;
    }

    // no character: seeds land one after another and spread with a liquid edge
    float diag = length(size);
    float f = 10.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 at = vec2(hash(vec2(seed, fi * 1.7)), hash(vec2(fi * 3.1, seed))) * size;
        f = min(f, fi / 4.0 * 0.25 + distance(p, at) / diag * 1.9);
    }
    f += (fbm(p / 260.0 + seed) - 0.5) * 0.22; // the front wobbles like liquid
    float front = progress * 1.45 - 0.05;
    alpha = arrived(f, front);
    float dist = front - f;
    rim = exp(-pow(dist / 0.02, 2.0)) * step(0.0001, progress) * (1.0 - smoothstep(0.85, 1.0, progress));
    glow = exp(-max(-dist, 0.0) / 0.04) * (1.0 - alpha) * step(0.0001, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    col = mix(col, glowTone, rim * 0.7);
    vec4 outer = vec4(tone.rgb * 0.5 * glow, 0.4 * glow);
    if (progress >= 0.995) {
        alpha = 1.0;
        col = pic;
        outer = vec4(0.0);
    }
    vec4 face = vec4(col * alpha, alpha);
    fragColor = (face + outer * (1.0 - alpha)) * qt_Opacity;
}
