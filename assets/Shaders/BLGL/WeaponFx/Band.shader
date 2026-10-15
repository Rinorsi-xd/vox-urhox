shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock=0.0;
varying float gain;
void vertex(){gain=NORMAL.x;}
void fragment(){
    float r=length(UV);
    float a=(1.0-smoothstep(0.0,0.18,abs(r-0.9)))*gain*step(0.7,r)*step(r,1.0);
    if(a<0.003 || planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS))discard;ALBEDO=COLOR.rgb*16.0*a;ALPHA=1.0;
}
