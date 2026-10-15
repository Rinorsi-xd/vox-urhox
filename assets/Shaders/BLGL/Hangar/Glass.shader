shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, blend_mix, depth_draw_never, cull_back;
#include "../lib/VoxHemi.shaderinc"
uniform vec4 base_color=vec4(0.07,0.08,0.1,0.28);
uniform float roughness_value=0.05;
uniform float metallic_value=0.2;
uniform float coat=1.0;
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 ALBEDO=base_color.rgb; ALPHA=base_color.a;
 ROUGHNESS=roughness_value; METALLIC=metallic_value;
 CLEARCOAT=coat; CLEARCOAT_ROUGHNESS=0.1;
 EMISSION=vox_hemi(ALBEDO,METALLIC,NORMAL);
}
