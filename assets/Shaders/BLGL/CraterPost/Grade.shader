// Original crater GradeShader, Three ACESFilmicToneMapping, then sRGB output.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform sampler2D bloom_map : filter_linear, repeat_disable;
uniform float exposure=1.1;
uniform float bloom_weight=1.0;
void fragment() {
    vec3 c=max(texture(source_map,UV).rgb+texture(bloom_map,UV).rgb*bloom_weight,vec3(0.0));
    float w=smoothstep(0.02,0.6,dot(c,vec3(0.2126,0.7152,0.0722)));
    c*=mix(vec3(0.93,0.98,1.05),vec3(1.06,1.0,0.91),w);
    c=0.18*pow(c/0.18+vec3(0.00001),vec3(1.08));
    c=max(mix(vec3(dot(c,vec3(0.2126,0.7152,0.0722))),c,1.05),vec3(0.0))*exposure/0.6;
    c=mat3(vec3(0.59719,0.076,0.02840),vec3(0.35458,0.90834,0.13383),vec3(0.04823,0.01566,0.83777))*c;
    c=(c*(c+0.0245786)-0.000090537)/(c*(0.983729*c+0.432951)+0.238081);
    c=clamp(mat3(vec3(1.60475,-0.10208,-0.00327),vec3(-0.53108,1.10813,-0.07276),vec3(-0.07367,-0.00605,1.07602))*c,0.0,1.0);
    ALBEDO=mix(c*12.92,1.055*pow(c,vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
