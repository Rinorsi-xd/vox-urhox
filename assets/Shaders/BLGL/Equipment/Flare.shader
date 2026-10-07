shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D flow_map : filter_linear_mipmap, repeat_enable;
uniform float clock=0.0;
varying vec3 settings;
void vertex(){settings=NORMAL;}
void fragment(){
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    vec2 uv=UV*0.5+0.5;float d=length(UV);
    float n=texture(flow_map,uv*0.55+vec2(settings.y,-clock*0.55)).r;
    float a=exp(-d*d*5.0)*(1.0-smoothstep(0.52,0.94,d));
    float core=exp(-d*d*20.0),axial=settings.z;
    vec3 c=vec3(0.06,0.43,1.2)*a*(0.35+0.65*n)+vec3(0.45,0.9,1.25)*core*axial;
    ALBEDO=c*settings.x*(0.3+0.7*axial);ALPHA=1.0;
}
