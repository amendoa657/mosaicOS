#version 440
// The new wallpaper comes in as pixel colonies: a few seeds land at random
// places and grow, eating the old wallpaper in crisp square cells. Each cell
// lights up for an instant in the new wallpaper's most vivid colour (`tone`)
// as it turns, then settles into the picture.
// Idea from pocket-dots' "contagio" (diegoMalagrida/pocket-dots, GPL-3.0). The
// pocket bakes the cells' arrival times into a map with a Python script; here
// they are worked out right in the shader: a cell's arrival is its distance to
// the nearest seed (each seed starting a little later than the one before),
// plus a bit of noise so the fronts are ragged, not round.
// Only the new picture is drawn (where it has arrived); the old wallpaper is
// simply what is underneath, so nothing needs to match it.
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o colonies.frag.qsb colonies.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source; // the new wallpaper

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // screen size (px)
    vec2 picSize;   // image size (px), to crop it like the wallpaper does
    float progress; // 0..1
    float seed;     // a different layout of seeds every time
    vec4 tone;      // the burning colour
};

const int SEEDS = 5;
const float SPAN = 1.3; // about the latest a cell arrives (see arrival()); the last ones are forced in at the end

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// "cover" crop: the image fills the screen, centred
vec3 pick(vec2 p) {
    float s = max(size.x / picSize.x, size.y / picSize.y);
    vec2 uv = ((p - size * 0.5) / s + picSize * 0.5) / picSize;
    return texture(source, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

// when this cell turns: the nearest seed in "time", 0..SPAN
float arrival(vec2 cellCentre) {
    float diag = length(size);
    float best = 10.0;
    for (int i = 0; i < SEEDS; i++) {
        float fi = float(i);
        vec2 at = vec2(hash(vec2(seed, fi * 1.7)), hash(vec2(fi * 3.1, seed))) * size;
        float start = fi / float(SEEDS) * 0.3; // seeds land one after another
        best = min(best, start + distance(cellCentre, at) / diag * 2.4);
    }
    return best + hash(cellCentre + seed) * 0.06;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float cell = 8.0 * max(1.0, size.y / 1080.0); // 8 px cells on a 1080p screen
    vec2 c = floor(p / cell) * cell + cell * 0.5;

    float now = clamp(progress, 0.0, 1.0) * SPAN;
    float t = arrival(c);
    if (now < t && progress < 0.995) {
        fragColor = vec4(0.0);
        return;
    }
    // just turned: burning in the tone, cooling into the picture
    float age = (now - t) / 0.08;
    vec3 col = mix(tone.rgb, pick(p), smoothstep(0.0, 1.0, age));
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
