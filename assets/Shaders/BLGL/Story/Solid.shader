shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;
uniform vec3 uColor=vec3(1.0);
uniform float opacity=1.0;
uniform float uReveal=99.0;
void fragment(){if(length(VERTEX.xz)>uReveal) discard;ALBEDO=pow(uColor*opacity,vec3(2.2));ALPHA=1.0;}
