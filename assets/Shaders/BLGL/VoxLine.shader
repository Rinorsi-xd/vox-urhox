// 档位外包络虚线（对应 H5 的 LineBasicMaterial：线性颜色 (1.1, 0.72, 0.2)、不透明度 0.32）
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 line_rgb = vec3(1.1, 0.72, 0.2);
uniform float line_alpha = 0.32;

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = line_rgb;
    ALPHA = line_alpha;
}
