#version 440

// The new wallpaper pours over the old one: a puddle grows from the point you
// clicked, with a wobbly liquid edge, a bright rim (the meniscus) and the image
// bent a little near the edge, as if seen through the water.
// Inspired by hyprdots' wallpour2.frag (fedyaqq34356/hyprdots, GPL-3.0).
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o pour.frag.qsb pour.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source; // the new wallpaper

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;     // screen size (px)
    vec2 picSize;  // image size (px), to crop it like the wallpaper does
    vec2 sink;     // where the liquid starts (px)
    float progress;// 0..1
    vec4 tone;     // the accent colour for the rim
};

// "cover" crop: the image fills the screen, centred
vec3 pick(vec2 p) {
    float s = max(size.x / picSize.x, size.y / picSize.y);
    vec2 uv = ((p - size * 0.5) / s + picSize * 0.5) / picSize;
    return texture(source, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float e = clamp(progress, 0.0, 1.0);
    float S = size.y / 1080.0; // keeps sizes the same on any resolution

    vec2 dv = p - sink;
    float r = length(dv);
    float a = atan(dv.y, dv.x);
    vec2 n = dv / max(r, 1e-3);

    // radius needed to cover the farthest corner, then eased so it starts fast
    float rmax = length(max(sink, size - sink)) + 80.0 * S;
    float R = (1.0 - pow(1.0 - e, 1.7)) * rmax;

    // the wobble of the edge, strongest mid-way
    float wob = (sin(a * 5.0 + e * 7.0) * 0.55 + sin(a * 9.0 - e * 11.0) * 0.3) * 18.0 * S * sin(3.14159265 * e);
    float d = r - (R + wob); // < 0 inside the puddle

    // near the edge the image is pushed outwards (refraction) with small ripples
    float thick = exp(min(d, 0.0) / (34.0 * S)) * step(d, 0.0);
    float ripple = sin((r - R) / (9.0 * S) - e * 30.0) * 3.0 * S * thick;
    vec3 col = pick(p - n * (thick * 22.0 * S + ripple));

    // meniscus: a thin bright rim lit from the top left, tinted with the accent
    float men = exp(-pow((d + 3.0 * S) / (2.2 * S), 2.0));
    float light = 0.5 + 0.5 * cos(a + 2.2);
    col += men * (vec3(0.55) * light + tone.rgb * 0.35);

    float aa = max(fwidth(d), 0.8);
    float alpha = clamp(0.5 - d / aa, 0.0, 1.0);
    // a soft glow just outside the edge while it moves
    float band = exp(-max(d, 0.0) / (10.0 * S)) * (1.0 - alpha) * step(0.001, e) * (1.0 - smoothstep(0.85, 1.0, e));
    vec4 outer = vec4(tone.rgb * 0.08 * band, 0.35 * band);

    fragColor = (vec4(col * alpha, alpha) + outer * (1.0 - alpha)) * qt_Opacity;
}
