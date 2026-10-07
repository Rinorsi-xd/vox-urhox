// 光束（悬浮器光柱、推进器尾焰、车灯光束）：沿本地 +Y 渐隐的加色半透明体
// use_instance_color = 1 时颜色取实例色（车灯光束 = 涂装颜色）。
// 加色混合：预乘混合 + ALPHA = 0，结果 = 目标色 + 光束色。
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 beam_color = vec4(0.22, 0.85, 1.0, 1.0);
uniform float use_instance_color = 0.0;
uniform float strength = 0.35;
uniform float y0 = 0.05;
uniform float y1 = 1.45;
uniform float soft_start = 0.0;

varying float local_y;
varying vec4 inst_color;

void vertex() {
    local_y = VERTEX.y;
    inst_color = INSTANCE_COLOR;
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float t = clamp((local_y - y0) / (y1 - y0), 0.0, 1.0);
    float fade = pow(1.0 - t, 1.6);
    if (soft_start > 0.0) {
        fade *= smoothstep(0.0, soft_start, t); // 灯口处透明，向前才显出光束
    }
    vec3 to_cam = CAMERA_POSITION_WORLD - VERTEX;
    float facing = pow(abs(dot(normalize(NORMAL), normalize(to_cam))), 1.4);
    float near_fade = smoothstep(0.6, 3.5, length(to_cam)); // 镜头贴近光束时淡出
    vec3 col = mix(beam_color.rgb, inst_color.rgb, use_instance_color);
    ALBEDO = col * strength * fade * facing * near_fade * 2.0;
    ALPHA = 0.0;
}
