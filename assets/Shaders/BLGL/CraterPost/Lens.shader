shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform vec2 resolution=vec2(1920.0,1080.0);
uniform float vignette=0.3;
uniform float grain=0.0;
void fragment() {
    vec2 d=UV-0.5;
    vec2 offset=d*dot(d,d)*0.0006*4.0;
    vec3 c=vec3(texture(source_map,UV-offset).r,texture(source_map,UV).g,texture(source_map,UV+offset).b);
    float aspect=resolution.x/resolution.y;
    float t=clamp((length(d*vec2(aspect,1.0)/aspect)*1.25-0.85)/(0.2-0.85),0.0,1.0);
    c*=mix(1.0-vignette,1.0,t*t*(3.0-2.0*t));
    float noise=fract(sin(dot(UV*resolution,vec2(12.9898,78.233)))*43758.5453)-0.5;
    ALBEDO=c+noise*grain*(1.0-dot(c,vec3(0.299,0.587,0.114))*0.7);
}
