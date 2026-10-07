shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, blend_mix, cull_back, depth_draw_never;
#include "lib/VoxHemi.shaderinc"
uniform vec4 tint_color = vec4(1.0, 1.0, 1.0, 0.12);
uniform float use_instance_color = 1.0;
uniform float roughness_value = 0.5;
varying vec3 part_color;
void vertex() { part_color = INSTANCE_COLOR.rgb; }
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    ALBEDO = tint_color.rgb * mix(vec3(1.0), part_color, use_instance_color);
    ALPHA = tint_color.a;
    ROUGHNESS = roughness_value;
    METALLIC = 0.0;
    EMISSION = vox_hemi(ALBEDO, METALLIC, NORMAL);
}
