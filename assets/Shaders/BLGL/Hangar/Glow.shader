// 灯具周围的发光贴片（对应 H5 的 THREE.Sprite + glowTexture，加色混合）
// 一个网格装下所有贴片：顶点位置 = 贴片中心，UV = 角点 (-1..1)，UV2 = (尺寸, 不透明度)，顶点色 = 颜色。
// 顶点着色器把四个角沿相机的右 / 上方向展开，始终正对镜头。节点必须放在原点、不旋转不缩放。
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled;

varying vec2 corner;
varying vec3 tint;
uniform float hangar_time = 0.0;
uniform float blink_rate = 0.0;

// glowTexture 的径向渐变：0 → 1，0.2 → 0.45，0.5 → 0.12，1 → 0
float glow(float r) {
    if (r < 0.2) return mix(1.0, 0.45, r / 0.2);
    if (r < 0.5) return mix(0.45, 0.12, (r - 0.2) / 0.3);
    return mix(0.12, 0.0, clamp((r - 0.5) / 0.5, 0.0, 1.0));
}

void vertex() {
    corner = UV;
    tint = VERTEX_COLOR.rgb * UV2.y;
    vec3 right = INV_VIEW_MATRIX[0].xyz;
    vec3 up = INV_VIEW_MATRIX[1].xyz;
    VERTEX = VERTEX + (right * UV.x + up * UV.y) * (UV2.x * 0.5);
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float pulse = blink_rate > 0.0 && fract(hangar_time * blink_rate) >= 0.45 ? 0.08 : 1.0;
    ALBEDO = tint * glow(length(corner)) * pulse;
    ALPHA = 0.0;
}
