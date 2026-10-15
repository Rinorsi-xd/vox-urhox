shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;

	uniform float uTime = 0.0; uniform vec3 uColor = vec3(0.06125,0.57758,1.0); uniform float uR = 4.6; uniform float uGain = 1.0;
	  
	void fragment() {vec3 vP=VERTEX*vec3(-1.0,1.0,1.0);vec3 vW=vP;float vH=vP.y;float vS=1.0-NORMAL.y;vec3 vN=NORMAL;vec3 vV=VIEW;vec2 vUv=vec2(UV.x,1.0-UV.y);
		float r = length( vW.xz );
		if ( r > uR ) discard;
		float f = 1.0 - abs( dot( normalize( vN ), normalize( vV ) ) );
		float rim = pow( f, 1.6 );
		float lines = 0.8 + 0.2 * sin( vW.y * 260.0 );
		float scan = 1.0 - smoothstep( 0.0, 0.05, abs( fract( vW.z * 0.18 - uTime * 0.07 ) - 0.5 ) );
		float flick = 0.94 + 0.06 * sin( uTime * 23.0 + vW.x * 4.0 );
		float a = ( 0.1 + rim * 1.15 ) * lines * flick + scan * 0.3;
		a *= smoothstep( uR, uR - 0.3, r ) * uGain;
		vec3 col = mix( uColor, vec3( 1.0 ), rim * rim * 0.6 );
		ALBEDO=pow(max(col*a*a,vec3(0.0)),vec3(2.2));ALPHA=1.0;
	}