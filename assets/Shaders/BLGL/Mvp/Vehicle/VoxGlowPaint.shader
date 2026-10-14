// 发光涂装（车灯灯珠、天线信号灯）：发光颜色 = 实例色（涂装颜色）
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


uniform float glow_strength = 1.7;
uniform float use_vertex_color = 0.0;
uniform float roughness_value = 0.25;

varying vec4 inst_color;

void vertex() {
    inst_color = mix(INSTANCE_COLOR, COLOR, use_vertex_color);

vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
VERTEX=(inverse(MODEL_MATRIX)*vec4(mvp_deform(world),1.0)).xyz;
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = vec3(0.03);
    ROUGHNESS = roughness_value;
    METALLIC = 0.0;
    EMISSION = inst_color.rgb * glow_strength + vox_hemi(ALBEDO, METALLIC, NORMAL);
}
