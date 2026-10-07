// 带清漆层的固定色 PBR（碳纤维、卡钳、武器白色装甲）
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_back;
#include "lib/VoxHemi.shaderinc"

uniform vec4 base_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness_value = 0.4;
uniform float metallic_value = 0.0;
uniform float clearcoat_value = 1.0;
uniform float clearcoat_roughness_value = 0.1;

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = base_color.rgb;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    CLEARCOAT = clearcoat_value;
    CLEARCOAT_ROUGHNESS = clearcoat_roughness_value;
    EMISSION = vox_hemi(ALBEDO, METALLIC, NORMAL);
}
