shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock = 0.0;
uniform vec3 focus = vec3(0.0,-100000.0,0.0);
uniform float ceiling = 0.0;
varying float ground_height;
void vertex() { ground_height = NORMAL.y; }
float h21(vec2 p) { p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y); }
vec3 hexCell(vec2 p) {
    vec2 s=vec2(1.0,1.7320508);
    vec4 c=floor(vec4(p,p-vec2(0.5,1.0))/s.xyxy)+0.5;
    vec4 h=vec4(p-c.xy*s,p-(c.zw+0.5)*s);
    vec4 q=dot(h.xy,h.xy)<dot(h.zw,h.zw)?vec4(h.xy,c.xy):vec4(h.zw,c.zw+0.5);
    vec2 a=abs(q.xy);return vec3(0.5-max(dot(a,s*0.5),a.x),q.zw);
}
void fragment() {
    vec3 d=VERTEX-focus;
    float dist=ceiling>0.5?length(vec2(abs(d.y),length(d.xz)*0.5)):length(vec2(length(d.xz),d.y*0.7));
    float near=1.0-smoothstep(6.0,40.0,dist),n2=near*near;
    if(near<=0.001) discard;
    float gap=ceiling>0.5?abs(d.y):length(d.xz);
    float warn=1.0-smoothstep(9.0,12.6,length(d));
    vec3 hc=hexCell(UV/2.0);float fw=fwidth(hc.x);
    float hexEdge=(1.0-smoothstep(0.0,max(fw*1.3,0.01),hc.x-0.012))*(1.0-smoothstep(0.03,0.09,fw));
    float id=h21(hc.yz),pulse=step(0.72,id)*(0.5+0.5*sin(clock*(0.8+id*1.6)+id*40.0));
    float sv=ceiling>0.5?length(d.xz)*0.25-clock*3.0:UV.y*0.35-clock*1.2;
    float scan=smoothstep(0.94,1.0,fract(sv*0.12));
    float rr=ceiling>0.5?length(d.xz):length(vec2(length(d.xz-normalize(d.xz+vec2(0.0001))*gap),d.y));
    float ring=(1.0-smoothstep(0.0,0.035,abs(fract(rr*0.12-clock*0.6)-0.5)))*(1.0-smoothstep(4.0,18.0,rr));
    float base=ceiling>0.5?0.0:1.0-smoothstep(0.0,2.5,abs(VERTEX.y-ground_height));
    float blink=step(0.5,fract(clock*2.2)),w=smoothstep(0.35,0.65,warn);
    vec3 col=mix(vec3(0.04,0.42,1.0),vec3(1.0,0.45,0.02),w)*mix(1.0,0.55+0.75*blink,w);
    float glow=(hexEdge*(0.6+0.5*w)+pulse*0.07+scan*(0.05+0.35*hexEdge)+ring*0.45+base*0.7)*(0.25*near+0.75*n2);
    float fill=(0.4+0.1*w+pulse*0.08)*n2;
    ALBEDO=col*glow+mix(vec3(0.0,0.03,0.09),vec3(0.09,0.03,0.0),w)*fill;
    ALPHA=fill;
}
