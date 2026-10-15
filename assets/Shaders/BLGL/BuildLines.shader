shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard; ALBEDO = COLOR.rgb * 1.6; ALPHA = COLOR.a; }
