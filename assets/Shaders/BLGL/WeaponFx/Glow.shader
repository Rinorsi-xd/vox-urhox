shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock=0.0;
varying float gain;
void vertex(){gain=NORMAL.x;}
void fragment(){
    float r=length(UV);
    // Same two linear segments as the source; max avoids the DX11 compiler's
    // nested-predicate failure when a ternary is combined with discard.
    float a=max(1.0-0.25*r/0.22,0.75*(1.0-r)/0.78)*gain;
    if(a<0.004 || planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS))discard;
    ALBEDO=COLOR.rgb*16.0*a;ALPHA=1.0;
}
