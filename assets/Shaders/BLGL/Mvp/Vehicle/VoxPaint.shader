// 零件漆面（对应 H5 three/src/parts/materials.js 的 paintDetail）
// 颜色来自实例色（StaticModel.instanceColor，线性值）；实例色的 alpha 存一个 0~1 的随机数，
// 用来给每块零件一点点色差。同一种零件不管涂什么颜色都共用这一个材质，GPU 自动合批。
// block_edges = 1 时给方块做手绘风格的边缘提亮（建模单位为格，方块半边长 0.5）。
shader_type spatial;
#include "../Deform.shaderinc"
// This project has one planar reflector: the hangar floor at world Y=0.
// Reflection reverses the view basis, whereas main and shadow views do not.
// Keep the normal camera's full geometry, including partially submerged cars.
uniform vec4 planar_clip_plane = vec4(0.0, 1.0, 0.0, 0.0);
bool planar_clip_active(mat4 view, bool shadow_pass) {
    float orientation = dot(cross(view[0].xyz, view[1].xyz), view[2].xyz);
    return !shadow_pass && orientation < 0.0;
}
bool planar_clip_reject(vec3 world_position, mat4 view, bool shadow_pass) {
    return planar_clip_active(view, shadow_pass) && dot(vec4(world_position, 1.0), planar_clip_plane) < 0.0;
}

render_mode shading_model_pbr, cull_back;
// H5 场景里的 HemisphereLight：只照漫反射、不产生反射的天地渐变环境光。
// three.js 的算法：irradiance = mix(ground, sky, n.y * 0.5 + 0.5) × intensity，出射 = albedo × (1 - metallic) / π × irradiance。
// UrhoX 没有这种灯，各材质在 fragment 里把它加进 EMISSION（n 为世界空间法线）。
// 颜色为线性值；默认是车库的 天空 0xb8c6d8 / 地面 0x5a4634 / 强度 0.75，别的场景可按材质参数覆盖。
uniform vec3 hemi_sky = vec3(0.4793, 0.5648, 0.6868);
uniform vec3 hemi_ground = vec3(0.1023, 0.0612, 0.0343);
uniform float hemi_intensity = 0.75;

vec3 vox_hemi(vec3 albedo, float metallic, vec3 n) {
    float w = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
    return albedo * (1.0 - metallic) * mix(hemi_ground, hemi_sky, w) * (hemi_intensity * 0.318309886);
}


uniform float block_edges = 0.0;
uniform float use_vertex_color = 0.0;
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
    inst_color = mix(INSTANCE_COLOR, COLOR, use_vertex_color);

vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
VERTEX=(inverse(MODEL_MATRIX)*vec4(mvp_deform(world),1.0)).xyz;
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
