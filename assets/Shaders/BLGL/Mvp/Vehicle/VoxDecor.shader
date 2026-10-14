// Source rotating and emissive decor; shared GPU animation with source culling.
shader_type spatial;
#include "../Deform.shaderinc"
render_mode shading_model_pbr, cull_back;
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

// Source materials.js rotates in Three.js local space. Export mirrors X,
// so the equivalent native rotation uses the opposite sine signs.
uniform float animation_time = -1.0;
float vox_decor_time() { return animation_time < 0.0 ? TIME : animation_time; }
vec3 vox_decor_spin(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec3(c * p.x + s * p.z, p.y, c * p.z - s * p.x);
}

uniform vec4 base_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness_value = 0.5;
uniform float metallic_value = 0.0;
uniform vec4 emission_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;
uniform float spin_speed = 0.0;
uniform float blink = 0.0;
uniform float pulse_amount = 0.0;
void vertex() {
    float angle = vox_decor_time() * spin_speed;
    VERTEX = vox_decor_spin(VERTEX, angle);
    NORMAL = vox_decor_spin(NORMAL, angle);

vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
VERTEX=(inverse(MODEL_MATRIX)*vec4(mvp_deform(world),1.0)).xyz;
}
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float t = vox_decor_time();
    float intensity = emission_strength + (0.5 + 0.5 * sin(t * 1.1)) * pulse_amount;
    if (blink > 0.5) { intensity = fract(t * 0.9) < 0.14 ? 6.0 : 0.25; }
    ALBEDO = base_color.rgb;
    METALLIC = metallic_value;
    ROUGHNESS = roughness_value;
    EMISSION = emission_color.rgb * intensity + vox_hemi(ALBEDO, METALLIC, NORMAL);
}
