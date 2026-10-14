shader_type spatial;
render_mode shading_model_pbr,cull_disabled;
uniform vec4 tint=vec4(1.0);
uniform vec3 emission_color=vec3(0.0);
uniform float roughness_value=0.5;
uniform float metallic_value=0.0;
uniform sampler2D albedo_map : source_color,filter_linear_mipmap,repeat_disable;
uniform float has_map=0.0;
uniform float band=0.0;
uniform float spiral=0.0;
uniform float age=0.0;
void fragment(){
    vec4 t=mix(vec4(1.0),texture(albedo_map,UV*vec2(1.0+band,1.0)),has_map);
    ALBEDO=tint.rgb*mix(t.rgb,vec3(1.0),band);
    ROUGHNESS=roughness_value;METALLIC=metallic_value;
    float sp=fract(UV.x*3.0+(1.0-UV.y)*2.2-age*.9);
    float glow=smoothstep(0.0,.08,sp)*(1.0-smoothstep(.16,.28,sp))*2.2;
    EMISSION=emission_color*mix(vec3(mix(1.0,glow,spiral)),t.rgb,band);
}
