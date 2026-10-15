shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
uniform vec4 tint=vec4(1.0);
uniform float has_map=0.0;
uniform sampler2D albedo_map : source_color,filter_linear_mipmap,repeat_enable;
void fragment(){
    vec4 base=tint;
    if(has_map>0.5)base*=texture(albedo_map,UV);
    ALBEDO=base.rgb;ALPHA=base.a;
}
