shader_type spatial;
uniform vec3 uColor = vec3(1.0);
uniform float roughness = 0.5;
uniform float metalness = 0.0;
void fragment() { ALBEDO = uColor; ROUGHNESS = roughness; METALLIC = metalness; }
