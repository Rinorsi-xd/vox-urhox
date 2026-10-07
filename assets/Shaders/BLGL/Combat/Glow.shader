shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock = 0.0;
void fragment() {
    float r=length(UV);
    float a=r<0.18 ? mix(1.0,0.85,r/0.18) : (r<0.45 ? mix(0.85,0.28,(r-0.18)/0.27) : mix(0.28,0.0,clamp((r-0.45)/0.55,0.0,1.0)));
    ALBEDO=COLOR.rgb*16.0*COLOR.a*a; ALPHA=1.0;
}
