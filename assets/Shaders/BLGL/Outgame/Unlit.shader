shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 tint=vec4(1.0);uniform vec3 glow=vec3(0.0);uniform float roughness=0.8;uniform float metallic=0.0;
void fragment(){ALBEDO=tint.rgb*COLOR.rgb;EMISSION=glow;ROUGHNESS=roughness;METALLIC=metallic;}
