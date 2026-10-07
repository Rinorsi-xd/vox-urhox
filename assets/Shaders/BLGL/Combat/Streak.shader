shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock = 0.0;
varying vec3 parameters;
void vertex() { parameters=NORMAL; }
void fragment() {
    float a=UV.x; float radius=parameters.z*0.5; float len=parameters.y;
    float t=clamp(a/max(len,0.0001),0.0,1.0);
    float r=radius*mix(0.1,1.0,pow(t,0.7));
    if(a>len) r=sqrt(max(0.0,radius*radius-(a-len)*(a-len)));
    float x=abs(UV.y)*radius/max(r,0.0001);
    if(x>=1.0) discard;
    float glow=(1.0-x)*(1.0-x);
    float core=(1.0-smoothstep(0.0,parameters.x,x))*(0.25+0.75*t*t);
    vec3 col=COLOR.rgb*16.0;
    ALBEDO=(col*glow*mix(0.235,1.0,t)+mix(col,vec3(dot(col,vec3(0.33))),0.7)*core*2.0)*COLOR.a;
    ALPHA=1.0;
}
