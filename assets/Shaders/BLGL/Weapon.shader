// Source weaponFlow. Authored cell-space origin is per drawable, not world space.
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_back;
#include "lib/VoxHemi.shaderinc"
uniform vec4 base_color=vec4(0.02,0.02,0.02,1.0);
uniform float roughness_value=0.4;
uniform float metallic_value=0.0;
uniform vec4 emission_color=vec4(0.1,0.5,1.0,1.0);
uniform float emission_strength=1.0;
uniform vec4 flow_span=vec4(0.0,1.0,0.0,0.0); // tail z, muzzle z, pivot x/z
uniform vec4 flow_state=vec4(0.0,2.5,0.5,1.0); // phase, frequency, amplitude, power
uniform vec2 flow_sweep=vec2(-1.0,0.0);
varying float weapon_flow;
void vertex(){
    vec3 p=vec3(-VERTEX.x,VERTEX.y,VERTEX.z)+INSTANCE_CUSTOM.xyz;
    float axis=(p.z-flow_span.x)/max(0.01,flow_span.y-flow_span.x);
    float ring=fract(atan(p.z-flow_span.w,p.x-flow_span.z)/6.283185307+1.0);
    weapon_flow=mix(axis,ring,INSTANCE_CUSTOM.w);
}
void fragment(){
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float wv=0.5+0.5*sin((weapon_flow*flow_state.y-flow_state.x)*6.2831853);
    float band=wv*wv*wv*wv*wv*wv;
    float flow=1.0-flow_state.z+flow_state.z*(0.3+2.2*band);
    float sweep=flow_sweep.y*exp(-pow((weapon_flow-flow_sweep.x)*7.0,2.0));
    ALBEDO=base_color.rgb;ROUGHNESS=roughness_value;METALLIC=metallic_value;
    EMISSION=emission_color.rgb*emission_strength*(flow*flow_state.w+sweep*3.5)+vox_hemi(ALBEDO,METALLIC,NORMAL);
}
