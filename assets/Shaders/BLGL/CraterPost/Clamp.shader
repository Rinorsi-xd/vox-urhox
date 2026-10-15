shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform vec2 shaft_sun=vec2(0.5);
uniform float shaft_on=0.0;
uniform float shaft_aspect=1.0;
uniform float shaft_strength=0.3;
uniform vec3 shaft_color=vec3(1.0,0.8,0.55);
float shaftHash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment() {
    vec3 c=texture(source_map,UV).rgb;
    // H5 ShaftShader then ClampShader, fused without another full-size target.
    // Keep H5 bottom-up UV for its stochastic start; textures here are top-down.
    if(shaft_on>=0.002){
        vec2 webUV=vec2(UV.x,1.0-UV.y);
        vec2 sun=vec2(shaft_sun.x,1.0-shaft_sun.y);
        vec2 d=(sun-webUV)/36.0*0.92;
        vec2 uv=webUV+d*shaftHash(webUV*913.0);
        float sum=0.0,weight=1.0;
        for(int i=0;i<36;i++){
            uv+=d;
            vec4 sampleColor=texture(source_map,clamp(vec2(uv.x,1.0-uv.y),0.0,1.0));
            float lum=dot(sampleColor.rgb,vec3(0.2126,0.7152,0.0722));
            vec2 q=(uv-sun)*vec2(shaft_aspect,1.0);
            sum+=(1.0-sampleColor.a)*max(lum-0.9,0.0)*exp(-dot(q,q)*4.0)*weight;
            weight*=0.965;
        }
        c+=shaft_color*(sum/36.0)*shaft_strength*shaft_on;
    }
    c=clamp(c,0.0,65000.0);
    ALBEDO=c*min(1.0,4.0/max(max(max(c.r,c.g),c.b),0.0001));
}
