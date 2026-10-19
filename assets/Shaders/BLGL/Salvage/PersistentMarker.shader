shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 uColor = vec3(1.0);
uniform float uOpacity = 0.0;
void fragment() { ALBEDO = uColor; ALPHA = uOpacity * (1.0 - UV.y * UV.y); }
