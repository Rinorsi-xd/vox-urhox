shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint_color = vec4(0.05, 0.79, 1.0, 1.0);
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    vec2 d = abs(UV - vec2(0.5));
    float edge = smoothstep(0.41, 0.49, max(d.x, d.y));
    float corner = step(0.3, min(d.x, d.y)) * edge;
    ALBEDO = tint_color.rgb * (1.2 + edge * 2.0);
    ALPHA = edge * 0.55 + corner * 0.45 + 0.06 * (0.6 + 0.4 * sin(TIME * 6.0));
}
