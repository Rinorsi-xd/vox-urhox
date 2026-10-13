shader_type spatial;
render_mode unshaded;
uniform vec3 uColor = vec3(1.0);
void fragment() { ALBEDO = uColor; }
