shader_type spatial;
render_mode cull_disabled;
uniform sampler2D flag_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 uColor = vec3(1.0);
void fragment() { ALBEDO = texture(flag_map, UV).rgb * uColor; ROUGHNESS = 0.8; }
