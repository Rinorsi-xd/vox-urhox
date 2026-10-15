shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_premul_alpha, depth_draw_never, fog_disabled;
uniform float uOpacity=0.16;
void fragment(){
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;ALBEDO=vec3(0.75,0.79,0.85)*uOpacity;ALPHA=0.0;}
