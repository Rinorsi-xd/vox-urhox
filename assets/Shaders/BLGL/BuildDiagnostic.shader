shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_mix, cull_back, depth_draw_never;
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard; ALBEDO = COLOR.rgb * 2.0; ALPHA = COLOR.a; }
