shader_type spatial;
render_mode shading_model_pbr,cull_back;
uniform sampler2D groundBaked : filter_linear_mipmap, repeat_disable;
void fragment(){
    vec2 uv=(VERTEX.xz+vec2(1024.0))/2048.0;
    vec4 gc=texture(groundBaked,uv);
    ALBEDO=pow(gc.rgb,vec3(2.2));ROUGHNESS=gc.a;
}
