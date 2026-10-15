shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 uColor = vec3(0.275, 0.784, 1.0);
uniform float uTime = 0.0;
uniform float opacity = 0.32;
void fragment() {
    float y = 1.0 - UV.y;
    float a = pow(1.0 - y, 1.6) * opacity * (0.75 + 0.25 * sin(y * 60.0 - uTime * 6.0));
    ALBEDO = uColor * a; ALPHA = a;
}
