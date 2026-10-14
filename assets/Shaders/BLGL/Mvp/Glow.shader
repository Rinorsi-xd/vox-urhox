shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec4 tint=vec4(1.0);
uniform sampler2D albedo_map : source_color,filter_linear,repeat_disable;
uniform float has_map=0.0;
void fragment(){vec4 t=mix(vec4(1.0),texture(albedo_map,UV),has_map);ALBEDO=t.rgb*tint.rgb;ALPHA=t.a*tint.a;}
