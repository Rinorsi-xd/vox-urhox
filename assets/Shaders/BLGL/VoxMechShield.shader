// Frozen shieldMaterial: local scanning bands plus the leg's landing pulse.
shader_type spatial;
render_mode shading_model_pbr, cull_back;
#include "lib/VoxHemi.shaderinc"
#include "lib/PlanarClip.shaderinc"
uniform vec4 base_color = vec4(0.0);
uniform vec4 emission_color = vec4(0.0);
uniform float emission_strength = 0.85;
uniform float roughness_value = 0.16;
uniform float band_base = 0.55;
uniform float band_strength = 1.1;
varying vec3 shield_pos;
varying float shield_pulse;
void vertex() {
    shield_pos = vec3(-VERTEX.x, VERTEX.y, VERTEX.z);
    shield_pulse = INSTANCE_CUSTOM.x;
}
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float wave = sin(dot(shield_pos, vec3(0.35, 1.0, 0.55)) * 1.6 - TIME * 2.4);
    float band = smoothstep(0.45, 1.0, wave);
    ALBEDO = base_color.rgb;
    ROUGHNESS = roughness_value;
    METALLIC = 0.08;
    EMISSION = emission_color.rgb * emission_strength * (band_base + band_strength * band + 1.8 * shield_pulse)
        + vox_hemi(ALBEDO, METALLIC, NORMAL);
}
