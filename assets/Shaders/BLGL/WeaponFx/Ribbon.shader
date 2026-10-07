shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock=0.0;
varying vec3 parameters;
void vertex(){parameters=NORMAL;}
void fragment(){
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float x=abs(UV.y);float glow=pow(max(0.0,1.0-x),2.4);
    float core=parameters.x>0.0 ? 1.0-smoothstep(parameters.x*0.25,parameters.x,x) : 0.0;
    float ends=smoothstep(0.0,0.04,UV.x)*(1.0-smoothstep(0.96,1.0,UV.x));
    vec3 col=COLOR.rgb*16.0;
    ALBEDO=(col*glow+mix(col,vec3(dot(col,vec3(0.33))),0.65)*core*2.2)*COLOR.a*ends;ALPHA=1.0;
}
