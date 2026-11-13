#version 440
// Mosaic OS: the mosaic-ui pixel wave (mosaicStore js/transicao.js) over one
// widget: the card starts covered by squares in the theme's four tones, and they
// shrink away in a wave that starts at `origin`, revealing what is under them.
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o pixelwave.frag.qsb pixelwave.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // px
    vec2 origin;    // 0..1, where the wave starts
    float progress; // 0 covered .. 1 revealed
    float cell;     // square size, px
    float radius;   // the card's corner, px
    vec4 tone0;
    vec4 tone1;
    vec4 tone2;
    vec4 tone3;
};
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
void main() {
    vec2 p = qt_TexCoord0 * size;
    // inside the rounded card only
    vec2 q = abs(p - size * 0.5) - (size * 0.5 - radius);
    float card = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    if (card > 0.0) { fragColor = vec4(0.0); return; }
    vec2 id = floor(p / cell);
    vec2 centre = (id + 0.5) * cell;
    float dist = distance(centre / size, origin) / 1.42;
    float jitter = hash(id) * 0.18;
    float t = clamp((progress * 1.35 - dist * 0.85 - jitter) / 0.32, 0.0, 1.0);
    float s = 1.0 - t * t * (3.0 - 2.0 * t); // the square's side, 1 → 0
    vec2 d = abs(p - centre);
    float inside = step(max(d.x, d.y), s * (cell - 2.0) * 0.5); // a 2 px gap, as in mosaic-ui
    float k = hash(id + 7.0);
    vec4 tone = k < 0.25 ? tone0 : k < 0.5 ? tone1 : k < 0.75 ? tone2 : tone3;
    fragColor = vec4(tone.rgb, 1.0) * inside * qt_Opacity;
}
