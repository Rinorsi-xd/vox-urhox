// 零件漆面（对应 H5 three/src/parts/materials.js 的 paintDetail）
// 颜色来自实例色（StaticModel.instanceColor，线性值）；实例色的 alpha 存一个 0~1 的随机数，
// 用来给每块零件一点点色差。同一种零件不管涂什么颜色都共用这一个材质，GPU 自动合批。
// block_edges = 1 时给方块做手绘风格的边缘提亮（建模单位为格，方块半边长 0.5）。
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_back;
#include "lib/VoxHemi.shaderinc"

uniform float block_edges = 0.0;
uniform float roughness_value = 0.55;
uniform float metallic_value = 0.05;
uniform float clearcoat_value = 0.12;
uniform float clearcoat_roughness_value = 0.45;

varying vec3 local_p;
varying vec4 inst_color;

float p_hash(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float p_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = mix(mix(p_hash(i), p_hash(i + vec3(1.0, 0.0, 0.0)), f.x),
                  mix(p_hash(i + vec3(0.0, 1.0, 0.0)), p_hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
    float b = mix(mix(p_hash(i + vec3(0.0, 0.0, 1.0)), p_hash(i + vec3(1.0, 0.0, 1.0)), f.x),
                  mix(p_hash(i + vec3(0.0, 1.0, 1.0)), p_hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
    return mix(a, b, f.z);
}

void vertex() {
    local_p = VERTEX;
    inst_color = INSTANCE_COLOR;
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float v = inst_color.a;
    vec3 col = inst_color.rgb * (0.95 + v * 0.1);
    if (block_edges > 0.5) {
        vec3 q = abs(local_p);
        float mx = max(max(q.x, q.y), q.z);
        float mid = q.x + q.y + q.z - mx - min(min(q.x, q.y), q.z);
        float edge = smoothstep(0.37, 0.47, mid);
        float n = p_noise(local_p * 14.0 + v * 20.0);
        col = mix(col, col * 1.16 + 0.015, edge * (0.3 + 0.35 * n));
    }
    ALBEDO = col;
    ROUGHNESS = clamp(roughness_value + (p_noise(local_p * 9.0 + v * 7.0) - 0.5) * 0.24, 0.08, 1.0);
    METALLIC = metallic_value;
    CLEARCOAT = clearcoat_value;
    CLEARCOAT_ROUGHNESS = clearcoat_roughness_value;
    EMISSION = vox_hemi(ALBEDO, METALLIC, NORMAL);
}
