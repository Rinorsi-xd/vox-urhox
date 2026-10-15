shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
uniform float uTime;
float h2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n2(vec2 p){vec2 i=floor(p),f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(h2(i),h2(i+vec2(1,0)),u.x),mix(h2(i+vec2(0,1)),h2(i+vec2(1,1)),u.x),u.y);}
void fragment(){
    vec2 q=UV-0.5;float r=length(q)*2.0;
    vec2 o=vec2(COLOR.r*17.0,COLOR.r*9.0)+vec2(uTime*0.03,-uTime*0.05);
    float n=n2(UV*3.0+o)*0.6+n2(UV*7.0-o*1.7)*0.4;
    float a=smoothstep(1.0,0.25,r+(n-0.5)*0.7)*COLOR.a*COLOR.b;
    if(a<0.003)discard;
    float lit=0.55+0.45*clamp(dot(normalize(vec3(q.x,q.y+0.25,0.4)),vec3(0.0,1.0,0.3)),0.0,1.0);
    ALBEDO=mix(vec3(0.04231141,0.03310477,0.02732089),vec3(0.8963,0.5776,0.2961),lit*0.35)*COLOR.g*2.0*(0.8+0.4*n);
    ALPHA=a;
}
