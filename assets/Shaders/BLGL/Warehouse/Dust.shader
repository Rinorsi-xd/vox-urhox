// Frozen warehouse.js _air(): 900 seeds, original drift and screen-space size.
shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never;
#include "../lib/PlanarClip.shaderinc"
uniform float hangar_time=0.0;
varying float dust_alpha;
void vertex(){
    float seed=NORMAL.x;
    float t=hangar_time*(0.03+seed*0.03);
    vec3 p=VERTEX;
    p.x-=sin(t*3.0+seed*40.0)*1.4;
    p.z+=cos(t*2.1+seed*17.0)*1.4;
    p.y=mod(p.y+t*0.6,16.0);
    // Match source point diameter independent of render resolution and DPR.
    float radius=(0.05+seed*0.07)/abs(PROJECTION_MATRIX[1][1]);
    vec2 corner=UV*2.0-1.0;
    VERTEX=p+(INV_VIEW_MATRIX[0].xyz*corner.x+INV_VIEW_MATRIX[1].xyz*corner.y)*radius;
    dust_alpha=0.25+0.35*seed;
}
void fragment(){
    if(planar_clip_reject(VERTEX,VIEW_MATRIX,IN_SHADOW_PASS))discard;
    float d=length(UV-0.5);
    float a=1.0-smoothstep(0.0,0.5,d);
    ALBEDO=vec3(1.0,0.93,0.85)*a*dust_alpha*0.5;
    ALPHA=0.0;
}
