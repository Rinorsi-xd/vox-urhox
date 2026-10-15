shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock = 0.0;
varying float thickness;
void vertex() { thickness=NORMAL.x; }
void fragment() {
    float t=1.0-abs(length(UV)-(1.0-thickness))/thickness;
    float a=smoothstep(0.0,1.0,t)*COLOR.a;
    ALBEDO=COLOR.rgb*16.0*a; ALPHA=1.0;
}
