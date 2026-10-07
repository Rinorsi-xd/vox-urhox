shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 tint = vec4(1.0);
void fragment() { ALBEDO=tint.rgb; }
