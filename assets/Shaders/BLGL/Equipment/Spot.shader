shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float clock=0.0;
void fragment(){
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float r=length(UV),edge=1.0-smoothstep(0.65,1.0,r);
    float phase=fract(clock*0.22),ring=exp(-pow((r-0.2-phase*0.55)/0.08,2.0))*sin(phase*3.14159)*0.23;
    float core=exp(-r*r*10.0),haze=exp(-r*r*3.5);
    ALBEDO=(vec3(0.035,0.32,0.85)*haze+vec3(0.12,0.65,1.1)*(core*0.65+ring))*edge*COLOR.a*0.52;ALPHA=1.0;
}
