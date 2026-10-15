shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
void fragment() {
    ALBEDO = COLOR.rgb;
    ALPHA = COLOR.a;
}
