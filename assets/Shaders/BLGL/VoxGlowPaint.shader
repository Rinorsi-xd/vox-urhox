// 发光涂装（车灯灯珠、天线信号灯）：发光颜色 = 实例色（涂装颜色）
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_back;
#include "lib/VoxHemi.shaderinc"

uniform float glow_strength = 1.7;
uniform float use_vertex_color = 0.0;
uniform float roughness_value = 0.25;

varying vec4 inst_color;

void vertex() {
    inst_color = mix(INSTANCE_COLOR, COLOR, use_vertex_color);
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = vec3(0.03);
    ROUGHNESS = roughness_value;
    METALLIC = 0.0;
    EMISSION = inst_color.rgb * glow_strength + vox_hemi(ALBEDO, METALLIC, NORMAL);
}
