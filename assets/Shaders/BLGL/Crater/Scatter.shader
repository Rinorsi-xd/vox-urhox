shader_type spatial;
render_mode shading_model_pbr,cull_disabled;
float clamp01(float v){return clamp(v,0.0,1.0);}
#include "Fog.shaderinc"
#include "ScatterNormal.shaderinc"
uniform sampler2D albedo_map;uniform vec4 tint=vec4(1.0);uniform float roughness=1.0;uniform float alpha_cut=0.0;
void fragment(){vec4 a=texture(albedo_map,UV);ALBEDO=a.rgb*tint.rgb;ALPHA=a.a;ALPHA_SCISSOR_THRESHOLD=alpha_cut;ROUGHNESS=roughness;
NORMAL=craterScatterNormal(VERTEX,NORMAL,UV,FRONT_FACING?1.0:-1.0);
FOG=craterFog(VERTEX*vec3(-1.0,1.0,1.0),CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0));}
