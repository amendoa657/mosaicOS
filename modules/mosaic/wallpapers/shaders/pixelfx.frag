#version 440
// The wallpaper transition: mosaic-ui's pixel wave (mosaicStore
// js/pixels-worker.js, "cortina") over the whole screen.
// A wave leaves `origin` and crosses the screen. Each cell it reaches gets a
// square in one of four tones, which grows over the old wallpaper; once full,
// the cell turns into the new wallpaper and the square shrinks away over it.
// Where the wave has not arrived, nothing is drawn: the old wallpaper is simply
// what is underneath. The desk's widgets play the same wave on their own cards
// (desk/desktop/Widget.qml) when it reaches them, with these same tones.
//
// Timing, shared with Widget.qml: a cell starts at progress (dist + jitter) / K
// and takes W / K of the run; dist = distance to the origin over the farthest corner.
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o pixelfx.frag.qsb pixelfx.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source; // the new wallpaper
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // screen size (px)
    vec2 picSize;   // image size (px), to crop it like the wallpaper does
    vec2 origin;    // 0..1, where the wave starts
    float progress; // 0..1
    float cell;     // square size, px
    vec4 tone0;
    vec4 tone1;
    vec4 tone2;
    vec4 tone3;
};
const float W = 0.22;      // how long one cell takes, in progress units (before / K)
const float JITTER = 0.08; // a little disorder in the front, like mosaic-ui's
const float K = 1.0 + W + JITTER;
const float GROW = 0.42;   // share of a cell's time spent growing the square

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
// "cover" crop: the image fills the screen, centred
vec2 coverUv(vec2 p) {
    float s = max(size.x / picSize.x, size.y / picSize.y);
    return clamp(((p - size * 0.5) / s + picSize * 0.5) / picSize, vec2(0.0), vec2(1.0));
}
float easeOut(float x) { return 1.0 - pow(1.0 - x, 3.0); }

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 id = floor(p / cell);
    vec2 centre = (id + 0.5) * cell;
    vec2 o = origin * size;
    float far = max(max(length(o), length(o - vec2(size.x, 0.0))),
                    max(length(o - vec2(0.0, size.y)), length(o - size)));
    float dist = distance(centre, o) / far;
    float t = clamp((progress * K - dist - hash(id) * JITTER) / W, 0.0, 1.0);

    float k = hash(id + 7.0);
    vec4 tone = k < 0.25 ? tone0 : k < 0.5 ? tone1 : k < 0.75 ? tone2 : tone3;
    vec2 d = abs(p - centre);
    float half_ = (cell - 2.0) * 0.5; // a 2 px gap between squares, as in mosaic-ui

    vec4 col = vec4(0.0);
    if (t >= GROW) // the cell already shows the new picture
        col = vec4(texture(source, coverUv(p)).rgb, 1.0);
    float side = t < GROW ? easeOut(t / GROW) : 1.0 - easeOut((t - GROW) / (1.0 - GROW));
    if (t > 0.0 && t < 1.0 && max(d.x, d.y) <= side * half_)
        col = vec4(tone.rgb, 1.0);
    fragColor = col * qt_Opacity;
}
