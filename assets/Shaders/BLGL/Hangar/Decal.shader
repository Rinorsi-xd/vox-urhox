shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, blend_mix, depth_draw_never, cull_back;
#include "../lib/VoxHemi.shaderinc"
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity=1.0;
#include "Canvas.shaderinc"
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec4 c=texture(albedo_map,UV);
 if (canvas_enabled > 0.5) c=hangar_canvas(UV);
 ALBEDO=c.rgb; ALPHA=c.a*opacity; ROUGHNESS=0.7; METALLIC=0.0;
 EMISSION=vox_hemi(ALBEDO,METALLIC,NORMAL);
}
