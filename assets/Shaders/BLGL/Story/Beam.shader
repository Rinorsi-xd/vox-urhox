shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;
uniform vec3 uColor = vec3(0.06125,0.57758,1.0);  void fragment() {vec3 vP=VERTEX*vec3(-1.0,1.0,1.0);vec3 vW=vP;float vH=vP.y;float vS=1.0-NORMAL.y;vec3 vN=NORMAL;vec3 vV=VIEW;vec2 vUv=vec2(UV.x,1.0-UV.y); float a = ( 1.0 - vUv.y ) * 0.85; ALBEDO=pow(max(uColor*a*a,vec3(0.0)),vec3(2.2));ALPHA=1.0; }