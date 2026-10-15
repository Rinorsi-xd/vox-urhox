shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform float threshold=1.3;
void fragment() {
    vec3 c=texture(source_map,UV).rgb;
    ALBEDO=c*smoothstep(threshold,threshold+0.01,dot(c,vec3(0.2126,0.7152,0.0722)));
}
