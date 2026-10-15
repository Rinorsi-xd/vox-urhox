shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 tint=vec4(1.0);
uniform sampler2D albedo_map : source_color,filter_linear,repeat_disable;
uniform float has_map=0.0;
void fragment(){ALBEDO=tint.rgb*mix(vec3(1.0),texture(albedo_map,UV).rgb,has_map);}
