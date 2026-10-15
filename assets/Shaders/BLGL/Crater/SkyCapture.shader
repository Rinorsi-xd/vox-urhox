shader_type sky;

			uniform vec3 uSun=vec3(-0.5209,0.5009,-0.6912);uniform float uTime=0.0;
			float h2( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }
			float n2( vec2 p ) { vec2 i = floor( p ), f = fract( p ); vec2 u = f * f * ( 3.0 - 2.0 * f );
				return mix( mix( h2( i ), h2( i + vec2( 1, 0 ) ), u.x ), mix( h2( i + vec2( 0, 1 ) ), h2( i + vec2( 1, 1 ) ), u.x ), u.y ); }
			void sky() {
				vec3 d = normalize(EYEDIR*vec3(-1.0,1.0,1.0));
				vec3 zen = vec3( 0.1590, 0.2270, 0.3185 ), hor = vec3( 0.4969, 0.3968, 0.2747 );
				float y = d.y;
				vec3 c = y > 0.0 ? mix( hor, zen, pow( min( y * 1.6, 1.0 ), 0.55 ) ) : hor * ( 1.0 - min( - y * 2.0, 0.25 ) );
				float s = max( dot( d, uSun ), 0.0 );
				vec3 sunC = vec3( 1.0000, 0.8714, 0.6867 ), hazeC = vec3( 0.8963, 0.5776, 0.2961 );
				c = mix( c, hazeC * 1.2, pow( s, 5.0 ) * 0.55 * ( 1.0 - min( max( y, 0.0 ) * 1.5, 0.8 ) ) );
				c += sunC * ( pow( s, 48.0 ) * 0.9 + pow( s, 600.0 ) * 6.0 );
				c += sunC * smoothstep( 0.99955, 0.9998, s ) * 40.0;
				// 薄云：投到高空平面上的两层噪声，靠近地平线淡掉
				if ( y > 0.02 ) {
					vec2 q = d.xz / ( y + 0.12 ) * 1.6 + vec2( uTime * 0.004, uTime * 0.002 );
					float cl = n2( q ) * 0.6 + n2( q * 2.7 + 3.1 ) * 0.4;
					cl = smoothstep( 0.55, 0.85, cl ) * smoothstep( 0.02, 0.25, y ) * 0.35;
					c = mix( c, mix( hor, sunC, 0.35 + 0.4 * pow( s, 3.0 ) ) * 1.15, cl );
				}
				COLOR=c;ALPHA=0.0;
			}