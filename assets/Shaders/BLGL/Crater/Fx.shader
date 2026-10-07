shader_type spatial;
render_mode unshaded,cull_disabled,blend_add,depth_draw_never;
float clamp01(float v){return clamp(v,0.0,1.0);}
#include "Fog.shaderinc"
uniform vec4 tint=vec4(1.0);void fragment(){ALBEDO=tint.rgb;ALPHA=tint.a;FOG=craterFog(VERTEX*vec3(-1.0,1.0,1.0),CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0));}
