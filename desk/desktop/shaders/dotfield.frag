#version 440
// Mosaic OS: the mosaic-ui living background (mosaicStore js/pixels.js): a grid
// of dots (15 px apart) where three slow waves, one per theme colour, fight over
// every dot; the winning wave's strength is the size of its little square. A
// 150 px lens follows the pointer and makes the dots under it bigger.
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o dotfield.frag.qsb dotfield.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;     // px
    vec2 pointer;  // px, (-1000,-1000) when away
    float time;    // s
    float pitch;   // px between dots
    float alpha;   // how strong the field is
    vec4 tone0;
    vec4 tone1;
    vec4 tone2;
};
float wave(vec2 p, vec2 dir, float freq, float speed, float phase) {
    return 0.5 + 0.5 * sin(dot(p, dir) * freq + time * speed + phase);
}
void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 id = floor(p / pitch);
    vec2 c = (id + 0.5) * pitch;
    vec2 u = c / max(size.x, size.y);
    float a = wave(u, normalize(vec2(1.0, 0.35)), 7.0, 0.35, 0.0) * wave(u, vec2(0.0, 1.0), 4.0, -0.22, 1.3);
    float b = wave(u, normalize(vec2(-0.6, 1.0)), 6.0, 0.28, 2.1) * wave(u, vec2(1.0, 0.0), 5.0, 0.18, 0.4);
    float g = wave(u, normalize(vec2(0.3, -1.0)), 8.0, -0.31, 4.2) * wave(u, normalize(vec2(1.0, 1.0)), 3.0, 0.25, 2.7);
    float m = max(a, max(b, g));
    vec4 tone = m == a ? tone0 : m == b ? tone1 : tone2;
    float lens = 1.0 - smoothstep(0.0, 150.0, distance(c, pointer));
    float side = pitch * (0.08 + 0.32 * m * m + 0.25 * lens);
    vec2 d = abs(p - c);
    float inside = step(max(d.x, d.y), side * 0.5);
    float k = alpha * (0.55 + 0.45 * m) + 0.35 * lens * alpha;
    fragColor = vec4(tone.rgb, 1.0) * inside * k * qt_Opacity;
}
