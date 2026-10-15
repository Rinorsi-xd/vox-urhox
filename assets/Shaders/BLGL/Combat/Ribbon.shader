shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock = 0.0;
varying vec3 parameters;
void vertex() { parameters = NORMAL; }
float hash(float n) { return fract(sin(n) * 43758.5453); }
float noise(float x) { float i=floor(x); float f=fract(x); f=f*f*(3.0-2.0*f); return mix(hash(i),hash(i+1.0),f); }
void fragment() {
    float x=abs(UV.y);
    float glow=pow(max(0.0,1.0-x),2.4);
    float core=parameters.x>0.0 ? 1.0-smoothstep(parameters.x*0.25,parameters.x,x) : 0.0;
    float n=0.55+0.9*noise(UV.x*2.2-clock*38.0)*noise(UV.x*2.2*0.37+clock*11.0+7.0);
    float ends=smoothstep(0.0,0.04,UV.x)*(1.0-smoothstep(0.96,1.0,UV.x));
    vec3 col=COLOR.rgb*16.0;
    ALBEDO=(col*glow*n+mix(col,vec3(dot(col,vec3(0.33))),0.65)*core*2.2)*COLOR.a*ends;
    ALPHA=1.0;
}
