shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;
uniform float elapsed=0.0;
uniform float power=0.0;
uniform float aspect=1.0;
uniform float pink=0.0;
uniform vec2 center=vec2(0.0);
float lane_hash(float n){return fract(sin(n*127.1+311.7)*43758.5453);}
void fragment(){
    vec2 p=vec2(UV.x*2.0-1.0,1.0-UV.y*2.0)-center;p.x*=aspect;
    float radius=length(p),angle=atan(p.y,p.x)/6.2831853+0.5;
    float lane=floor(angle*180.0),seed=lane_hash(lane);
    float narrow=1.0-smoothstep(0.035,0.20,abs(fract(angle*180.0)-0.5));
    float run=fract(radius*0.43-elapsed*(1.6+seed*1.5)+seed*9.0);
    float streak=smoothstep(0.12,0.32,run)*(1.0-smoothstep(0.64,0.96,run));
    float edge=smoothstep(0.40,1.1,radius);
    float alpha=narrow*streak*edge*step(0.38,seed)*power*0.5;
    if(alpha<0.003)discard;
    // Zero destination attenuation, with source intensity applied exactly once.
    vec3 color=mix(vec3(0.5,0.8,1.4),vec3(1.35,0.5,0.92),pink)*alpha;
    ALBEDO=pow(color,vec3(2.2));ALPHA=0.0;
}
