shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
uniform sampler2D smoke_map : filter_linear,repeat_disable;
uniform float age=0.0;
uniform float approach=0.0;
varying float opacity;
varying float gray;
void vertex(){
    float life=mix(2.6,2.2,approach);
    float u=clamp(age/life,0.0,1.0);
    // Closed form of source smoke's 60 Hz drag -> rise -> position updates.
    float n=floor(age*60.0),dt=1.0/60.0,k=exp(-0.9*dt),kn=pow(k,n);
    float travel=dt*k*(1.0-kn)/(1.0-k);
    float speed=mix(14.0,10.0,approach),radius=mix(3.0,4.0,approach),rise=mix(0.4,0.3,approach);
    float vy=mix(1.5,1.0,approach),steady=rise*dt/(1.0-k);
    float y=vy*travel+steady*(n*dt-travel);
    float tail=age-n*dt,kt=exp(-0.9*tail);
    float horizontal=radius+speed*(travel+kn*kt*tail);
    y+=((vy*kn+steady*(1.0-kn))*kt+rise*tail)*tail;
    vec3 p=vec3(-cos(NORMAL.x)*horizontal,mix(0.6,0.5,approach)+y,sin(NORMAL.x)*horizontal);
    float size=3.0+(mix(11.0,9.0,approach)-3.0)*(1.0-pow(1.0-u,2.2));
    float angle=NORMAL.y+NORMAL.z*age;vec2 q=(UV-0.5)*size;
    vec2 corner=vec2(q.x*cos(angle)-q.y*sin(angle),q.x*sin(angle)+q.y*cos(angle));
    VERTEX=p+INV_VIEW_MATRIX[0].xyz*corner.x+INV_VIEW_MATRIX[1].xyz*corner.y;
    opacity=min(1.0,u/0.15)*(1.0-u)*mix(0.55,0.45,approach);gray=0.55+u*0.12;
}
void fragment(){ALBEDO=vec3(gray);ALPHA=texture(smoke_map,UV).a*opacity;}
