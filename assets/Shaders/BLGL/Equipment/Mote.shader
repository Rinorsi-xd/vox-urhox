shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock=0.0;
void fragment(){
    float d=length(UV);if(d>1.0 || planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS))discard;
    ALBEDO=COLOR.rgb*16.0*exp(-d*d*5.0)*(1.0-smoothstep(0.5,1.0,d))*COLOR.a;ALPHA=1.0;
}
