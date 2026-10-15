shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float clock=0.0;
void fragment(){
    float r=length(UV);
    if(r<0.10/0.135||r>1.0 || planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS))discard;
    ALBEDO=COLOR.rgb*16.0;ALPHA=COLOR.a;
}
