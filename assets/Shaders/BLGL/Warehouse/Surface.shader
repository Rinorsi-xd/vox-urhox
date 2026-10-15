shader_type spatial;
render_mode shading_model_pbr,cull_back;
uniform vec4 tint=vec4(1.0);
uniform vec3 emission_color=vec3(0.0);
uniform float roughness_value=0.8;
uniform float metallic_value=0.0;
uniform float has_map=0.0;
uniform sampler2D albedo_map : source_color,filter_linear_mipmap,repeat_enable;
void fragment(){
    vec4 base=tint;
    if(has_map>0.5)base*=texture(albedo_map,UV);
    ALBEDO=base.rgb*COLOR.rgb;ROUGHNESS=roughness_value;METALLIC=metallic_value;EMISSION=emission_color;
}
