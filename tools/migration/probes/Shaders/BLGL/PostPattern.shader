shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float shaft_mode=0.0;
void fragment() {
    vec3 c=vec3(0.02+0.25*UV.x,0.04+0.4*UV.y,0.12);
    if (length(UV-vec2(0.35,0.4))<0.065) c=vec3(0.3,4.0,8.0);
    if (UV.x>0.61 && UV.x<0.64 && UV.y>0.2 && UV.y<0.78) c=vec3(5.0,2.0,0.03);
    float opacity=1.0;
    if(shaft_mode>0.5){
        c=vec3(2.0,1.8,1.3);opacity=0.0;
        if(length(UV-vec2(0.5))<0.07)c=vec3(40.0,35.0,27.0);
        if(UV.x>0.44 && UV.x<0.47){c=vec3(0.2,0.15,0.1);opacity=1.0;}
        if(shaft_mode>1.5)opacity=1.0;
    }
    ALBEDO=c;
    ALPHA=opacity;
}
