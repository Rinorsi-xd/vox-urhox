shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never;
uniform vec4 tint=vec4(1.0);
void fragment(){ALBEDO=tint.rgb*tint.a;ALPHA=0.0;}
