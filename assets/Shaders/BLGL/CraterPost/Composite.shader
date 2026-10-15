shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D level1 : filter_linear, repeat_disable;
uniform sampler2D level2 : filter_linear, repeat_disable;
uniform sampler2D level3 : filter_linear, repeat_disable;
uniform sampler2D level4 : filter_linear, repeat_disable;
uniform sampler2D level5 : filter_linear, repeat_disable;
uniform float strength=0.18;
uniform float radius=0.6;
void fragment() {
    ALBEDO=3.0*strength*(
        mix(1.0,0.2,radius)*texture(level1,UV).rgb+
        mix(0.8,0.4,radius)*texture(level2,UV).rgb+
        0.6*texture(level3,UV).rgb+
        mix(0.4,0.8,radius)*texture(level4,UV).rgb+
        mix(0.2,1.0,radius)*texture(level5,UV).rgb);
}
