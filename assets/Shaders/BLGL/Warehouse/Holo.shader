// Source trader sign: black pixels add no color; flicker is driven by warehouse.update.
shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never;
#include "../lib/PlanarClip.shaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 tint=vec4(1.0);
void fragment(){
    if(planar_clip_reject(VERTEX,VIEW_MATRIX,IN_SHADOW_PASS))discard;
    vec4 base=texture(albedo_map,UV)*tint;
    ALBEDO=base.rgb*base.a;
    ALPHA=0.0;
}
