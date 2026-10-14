shader_type spatial;
render_mode shading_model_pbr,blend_mix,cull_disabled,depth_draw_never;
uniform vec4 tint=vec4(1.0);
uniform vec3 emission_color=vec3(0.0);
uniform float roughness_value=0.8;
uniform float metallic_value=0.0;
void fragment(){ALBEDO=tint.rgb;ALPHA=tint.a;ROUGHNESS=roughness_value;METALLIC=metallic_value;EMISSION=emission_color;}
