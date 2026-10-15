shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float uOpacity = 0.0;
void fragment() { ALBEDO = vec3(1.0, 0.686685312, 0.351532600); ALPHA = uOpacity; }
