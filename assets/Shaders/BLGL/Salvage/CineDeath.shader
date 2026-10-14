shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never;
uniform sampler2D source_map : filter_linear,repeat_disable;
uniform float amount=0.0;
void fragment(){
    vec3 c=texture(source_map,UV).rgb;
    float gray=dot(c,vec3(0.2126,0.7152,0.0722));
    c=mix(c,vec3(gray),0.85*amount);
    c=(c-vec3(0.5))*(1.0+0.15*amount)+vec3(0.5);
    ALBEDO=max(c,vec3(0.0))*(1.0-0.15*amount);
}
