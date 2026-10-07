shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform sampler2D bloom_map : filter_linear, repeat_disable;
void fragment() { ALBEDO=texture(source_map,UV).rgb+texture(bloom_map,UV).rgb; }
