// 缓慢飘动的柔和尘埃（对应 H5 garage.js 的 dustMat，不闪烁）
// 顶点位置 = 粒子初始位置，UV = 角点 (-1..1)，UV2.x = 随机种子。节点放在原点。
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 dust_color = vec3(0.92, 0.9, 0.86);
uniform float hangar_time = 0.0;

varying vec2 corner;
varying float fade;

float glow(float r) {
    if (r < 0.2) return mix(1.0, 0.45, r / 0.2);
    if (r < 0.5) return mix(0.45, 0.12, (r - 0.2) / 0.3);
    return mix(0.12, 0.0, clamp((r - 0.5) / 0.5, 0.0, 1.0));
}

void vertex() {
    float seed = UV2.x;
    vec3 p = VERTEX;
    float t = hangar_time * (0.02 + seed * 0.02);
    p.x -= sin(t * 3.0 + seed * 40.0) * 1.2;
    p.z += cos(t * 2.3 + seed * 17.0) * 1.2;
    p.y = mod(p.y + t * 0.8, 22.0);
    fade = 0.3 + 0.3 * (1.0 - smoothstep(3.0, 14.0, length(p.xz)));
    // H5 用屏幕像素大小的点精灵：直径 ≈ (0.05~0.1) × 0.89 米（48° 视角）
    float size = (0.05 + seed * 0.06) * 0.89;
    corner = UV;
    vec3 right = INV_VIEW_MATRIX[0].xyz;
    vec3 up = INV_VIEW_MATRIX[1].xyz;
    VERTEX = p + (right * UV.x + up * UV.y) * (size * 0.5);
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = dust_color * glow(length(corner)) * fade * 0.5;
    ALPHA = 0.0;
}
