// 旗面：双面，颜色 = 实例色，随时间飘动（离旗杆越远摆幅越大）
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_disabled;
#include "lib/VoxHemi.shaderinc"

varying vec4 inst_color;

void vertex() {
    inst_color = INSTANCE_COLOR;
    float d = max(0.0, -VERTEX.z - 0.08);
    VERTEX.x += sin(VERTEX.z * 4.2 + TIME * 5.5 + VERTEX.y * 1.3) * 0.11 * d;
    VERTEX.y += sin(VERTEX.z * 3.1 + TIME * 3.7) * 0.03 * d;
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = inst_color.rgb;
    ROUGHNESS = 0.7;
    METALLIC = 0.0;
    EMISSION = vox_hemi(ALBEDO, METALLIC, FRONT_FACING ? NORMAL : -NORMAL);
}
