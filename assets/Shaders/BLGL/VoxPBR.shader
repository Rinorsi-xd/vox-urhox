// 通用固定色 PBR（零件的金属件、橡胶、发光灯条，以及车库场景）
shader_type spatial;
render_mode shading_model_pbr, cull_back;
#include "lib/VoxHemi.shaderinc"
#include "lib/PlanarClip.shaderinc"

uniform vec4 base_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness_value = 0.5;
uniform float metallic_value = 0.0;
uniform vec4 emission_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;
uniform float instance_emission = 0.0;
varying float equipment_emission;
void vertex() { equipment_emission=INSTANCE_CUSTOM.x; }

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = base_color.rgb;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    EMISSION = emission_color.rgb * mix(emission_strength,equipment_emission,instance_emission) + vox_hemi(ALBEDO, METALLIC, NORMAL);
}
