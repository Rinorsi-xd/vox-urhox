shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 uColor = vec3(0.24313725, 0.90196078, 1.0);
uniform float uBeamOpacity = 0.16;
uniform float uPhase = 0.0;
void fragment() {
    ALBEDO = uColor;
    ALPHA = mix(uBeamOpacity + sin(TIME * 2.0 + uPhase) * 0.03, 0.7, step(0.6, COLOR.a));
}
