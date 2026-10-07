shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_mix, cull_back, depth_draw_never;
uniform vec4 tint_color = vec4(0.05, 0.79, 1.0, 0.4);
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(CAMERA_POSITION_WORLD - VERTEX))), 2.2);
    float scan = 0.5 + 0.5 * sin(VERTEX.y * 38.0 - TIME * 6.0);
    ALBEDO = tint_color.rgb * (0.9 + rim * 2.6 + scan * 0.3);
    ALPHA = clamp(tint_color.a * (0.35 + 0.65 * rim) + scan * 0.06, 0.0, 0.9);
}
