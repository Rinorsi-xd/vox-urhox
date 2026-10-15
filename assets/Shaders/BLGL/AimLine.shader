shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void fragment() {
    float edge=1.0-smoothstep(0.65,1.0,abs(UV.y));
    ALBEDO=COLOR.rgb*COLOR.a*edge;
    ALPHA=1.0;
}
