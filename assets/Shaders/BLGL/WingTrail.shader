shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void fragment() { ALBEDO=COLOR.rgb*16.0; ALPHA=1.0; }
