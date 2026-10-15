shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float clock = 0.0;
void fragment() { ALBEDO=COLOR.rgb*16.0; ALPHA=COLOR.a; }
