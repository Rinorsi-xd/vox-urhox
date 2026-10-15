shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float clock = 0.0;
void fragment() {
    float r=length(UV);
    float a=r<0.25 ? mix(1.0,0.7,r/0.25) : mix(0.7,0.0,clamp((r-0.25)/0.75,0.0,1.0));
    ALBEDO=COLOR.rgb*16.0; ALPHA=COLOR.a*a;
}
