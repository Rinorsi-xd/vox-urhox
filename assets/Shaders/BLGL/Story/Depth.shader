shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_always,cull_disabled,fog_disabled;

	uniform float uR = 4.6; uniform float uReveal = 99.0;   
	void fragment() {vec3 vP=VERTEX*vec3(-1.0,1.0,1.0);vec3 vW=vP;float vH=vP.y;float vS=1.0-NORMAL.y;vec3 vN=NORMAL;vec3 vV=VIEW;vec2 vUv=vec2(UV.x,1.0-UV.y); if ( length( vW.xz ) > min( uR, uReveal ) ) discard; ALBEDO=vec3(0.0);ALPHA=0.0; }