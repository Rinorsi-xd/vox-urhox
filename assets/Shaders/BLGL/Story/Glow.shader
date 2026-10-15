shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock = 0.0;
void fragment() {
    float r=length(UV);
    float a=r<0.25 ? mix(1.0,0.45,r/0.25) : mix(0.45,0.0,clamp((r-0.25)/0.75,0.0,1.0));
    ALBEDO=COLOR.rgb*16.0*COLOR.a*a; ALPHA=1.0;
}
