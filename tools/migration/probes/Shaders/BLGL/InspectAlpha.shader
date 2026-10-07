shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform float mode=0.0;
void fragment(){
    vec4 c=texture(source_map,UV);
    ALBEDO=mode<0.5 ? vec3(c.a) : c.rgb/50.0;
}
