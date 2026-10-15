shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 uColor = vec3(0.24313725, 0.90196078, 1.0);
uniform float uClock = 0.0;
uniform float uProgress = 0.0;
void vertex() {
    if (COLOR.r > 0.5) {
        float a = uClock * 2.0;
        VERTEX.xz = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * VERTEX.xz;
        VERTEX.y += 4.5 + sin(uClock * 3.0) * 0.4;
    }
}
void fragment() {
    bool arc = COLOR.b > 0.5;
    if (arc && UV.x > max(0.001, uProgress)) { discard; }
    ALBEDO = arc ? vec3(1.0) : uColor;
    ALPHA = arc ? 0.95 : 0.6 + sin(uClock * 6.0) * 0.25;
}
