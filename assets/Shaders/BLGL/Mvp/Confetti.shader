shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float age=0.0;
uniform float top=3.1;
varying vec4 paper;
void vertex(){
    paper=COLOR;
    float id=VERTEX.y,seed=VERTEX.z;
    bool rain=id>=600.0;
    float born=rain?6.3+(id-600.0)/70.0:2.4;
    float a=age-born;
    if(rain&&a>=300.0/70.0)a=mod(a,300.0/70.0);
    vec3 velocity=NORMAL;
    float drag=rain?1.2:2.2,k=exp(-max(a,0.0)*drag);
    vec3 p=rain?vec3(sin(seed*2.3)*4.0,top+5.0+seed/3.0,cos(seed*3.1)*2.7):vec3(VERTEX.x*3.3,1.08,-.2);
    p+=velocity*(1.0-k)/drag;
    p.y-=3.136/drag*(max(a,0.0)-(1.0-k)/drag);
    p.x+=sin(age*3.0+seed)*.25*a;p.z+=cos(age*2.4+seed)*.2*a;
    vec2 q=(UV-.5)*vec2(.07,.04)*mix(.7,1.4,fract(seed));
    float spin=seed+a*(6.0+fract(seed)*10.0),c=cos(spin),s=sin(spin);
    vec3 corner=vec3(q.x*c-q.y*s,q.x*s+q.y*c,sin(spin*.7)*q.x);
    VERTEX=p+corner;
    if(a<0.0||a>9.0||p.y<-.5)VERTEX=vec3(0.0);
}
void fragment(){ALBEDO=paper.rgb;}
