#version 440

// Film grain over a rounded box (retro themes: the dock, any flat surface).
// Every pixel gets a fixed random value: above the middle it lightens, below it
// darkens, and `amount` says how much. Nothing outside the rounded box.
//
// Build: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o grain.frag.qsb grain.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;     // px
    float radius;  // corner radius (px)
    float amount;  // 0 = none
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float r = min(radius, min(size.x, size.y) * 0.5);
    vec2 d = abs(p - size * 0.5) - size * 0.5 + vec2(r);
    float sd = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
    float inside = 1.0 - smoothstep(-1.0, 0.0, sd);
    float n = hash(floor(p)) - 0.5;
    float a = abs(n) * 2.0 * amount * inside * qt_Opacity;
    fragColor = vec4(vec3(n > 0.0 ? 1.0 : 0.0) * a, a);
}
