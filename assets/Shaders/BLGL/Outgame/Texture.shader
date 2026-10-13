shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform sampler2D albedo;uniform vec4 tint=vec4(1.0);void fragment(){vec4 a=texture(albedo,UV);ALBEDO=a.rgb*tint.rgb;ALPHA=a.a*tint.a;}
