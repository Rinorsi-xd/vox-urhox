shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;

	uniform float uTime = 0.0; uniform vec3 uColor = vec3(0.06125,0.57758,1.0); 
	float line( float v, float w ) { float d = abs( fract( v - 0.5 ) - 0.5 ) / max( fwidth( v ), 1e-4 ); return 1.0 - min( d / w, 1.0 ); }
	float hash( float n ) { return fract( sin( n * 12.9898 ) * 43758.5453 ); }
	void fragment() {vec3 vP=VERTEX*vec3(-1.0,1.0,1.0);vec3 vW=vP;float vH=vP.y;float vS=1.0-NORMAL.y;vec3 vN=NORMAL;vec3 vV=VIEW;vec2 vUv=vec2(UV.x,1.0-UV.y);
		vec2 p = vW.xz;
		float r = length( p );
		float fade = smoothstep( 3.4, 5.6, r ) * smoothstep( 24.0, 9.0, r );
		if ( fade <= 0.002 ) discard;
		float fine = max( line( p.x / 0.25, 1.0 ), line( p.y / 0.25, 1.0 ) );
		float major = max( line( p.x, 1.4 ), line( p.y, 1.4 ) );
		float a = fine * 0.15 + major * 0.32;
		float s = 0.0;
		for ( int k = 0; k < 4; k ++ ) {
			float fk = float( k ), T = 6.5 + fk * 1.7, ph = uTime / T + fk * 0.31;
			float slot = floor( ph ), u = fract( ph );
			float h1 = hash( slot * 7.13 + fk * 3.31 ), h2 = hash( slot * 3.71 + fk * 9.17 ), h3 = hash( slot * 5.37 + fk * 1.73 );
			vec2 q = h1 > 0.5 ? p : p.yx;                    // q.x 横跨线的方向，q.y 沿线
			float at = floor( ( h2 * 2.0 - 1.0 ) * 10.0 );       // 走哪条主线（±10 以内）
			float dir = h3 > 0.5 ? 1.0 : - 1.0;
			float d = ( q.y - dir * mix( - 22.0, 22.0, u ) ) * dir;   // 相对流光头部的位置，负的在后面
			float tail = smoothstep( - 4.0, 0.0, d ) * step( d, 0.0 );
			float on = 1.0 - min( abs( q.x - at ) / max( fwidth( q.x ), 1e-4 ) / 1.8, 1.0 );
			s += on * tail * tail * sin( u * 3.14159 );
		}
		a = ( a + s * 0.9 ) * fade;
		vec3 c = mix( pow( uColor, vec3( 0.4545 ) ), vec3( 1.0 ), clamp( s, 0.0, 1.0 ) * 0.5 ); // uColor 是线性空间的，直接输出前转回 sRGB
		ALBEDO=pow(max(c*a,vec3(0.0)),vec3(2.2));ALPHA=1.0; // 叠加混合是 src × srcAlpha：alpha 给 1，亮度只乘一次 a（地形那边 col·a 再 ×a 是有意压暗的）
	}