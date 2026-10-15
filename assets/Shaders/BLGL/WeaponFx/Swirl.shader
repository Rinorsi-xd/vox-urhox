shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock=0.0;
varying float gain;
void vertex(){gain=NORMAL.x;}
void fragment(){
    float s=fract(UV.x*3.0-UV.y*1.6+clock*4.5);
    float a=smoothstep(0.0,0.25,s)*(1.0-smoothstep(0.25,0.6,s))*smoothstep(0.0,0.3,UV.y)*(1.0-smoothstep(0.55,1.0,UV.y))*gain;
    if(a<0.003 || planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS))discard;ALBEDO=COLOR.rgb*16.0*a;ALPHA=1.0;
}
