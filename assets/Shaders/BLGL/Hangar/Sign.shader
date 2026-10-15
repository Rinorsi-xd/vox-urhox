shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_back;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float strength=1.0;
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;ALBEDO=vec3(0.0);EMISSION=texture(albedo_map,UV).rgb*strength;ROUGHNESS=0.4;}
