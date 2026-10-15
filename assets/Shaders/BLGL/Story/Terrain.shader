shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;

	uniform float uTime = 0.0; uniform vec3 uColor = vec3(0.06125,0.57758,1.0); uniform float uR = 4.6;
	  
	float line( float v, float w ) { float d = abs( fract( v - 0.5 ) - 0.5 ) / max( fwidth( v ), 1e-4 ); return 1.0 - min( d / w, 1.0 ); }
	float hash( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }
	float vnoise( vec2 p ) { vec2 i = floor( p ), f = fract( p ); f = f * f * ( 3.0 - 2.0 * f );
		return mix( mix( hash( i ), hash( i + vec2( 1.0, 0.0 ) ), f.x ), mix( hash( i + vec2( 0.0, 1.0 ) ), hash( i + vec2( 1.0, 1.0 ) ), f.x ), f.y ); }
	void fragment() {vec3 vP=VERTEX*vec3(-1.0,1.0,1.0);vec3 vW=vP;float vH=vP.y;float vS=1.0-NORMAL.y;vec3 vN=NORMAL;vec3 vV=VIEW;vec2 vUv=vec2(UV.x,1.0-UV.y);
		float r = length( vP.xz );
		// 外沿渐隐：半径按两层噪声打散，从可玩区边上开始淡，到 EXT 淡没
		float n = vnoise( vP.xz * 0.9 ) * 0.6 + vnoise( vP.xz * 2.3 + 7.0 ) * 0.4;
		float edge = smoothstep( uR, 3.2, r + ( n - 0.5 ) * 1.1 );
		if ( edge <= 0.002 ) discard;
		vec2 m = vP.xz / 0.25;                             // 25 米一格
		float g = max( line( m.x, 1.3 ), line( m.y, 1.3 ) );
		float c = line( vH / 0.072, 1.2 );                 // 每 4 米一条等高线
		float scan = 1.0 - smoothstep( 0.0, 0.05, abs( fract( vP.z * 0.18 - uTime * 0.07 ) - 0.5 ) );
		float slope = clamp( vS * 5.0, 0.0, 1.0 );                   // 坡面亮一点，地形起伏看得出来
		float a = ( 0.07 + g * 0.42 + c * 0.38 + slope * 0.45 + scan * 0.22 ) * edge;
		vec3 col = uColor * ( 0.75 + 0.7 * clamp( vH * 1.4 + 0.35, 0.0, 1.0 ) );
		ALBEDO=pow(max(col*a*a,vec3(0.0)),vec3(2.2));ALPHA=1.0;
	}