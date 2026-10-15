shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never,fog_disabled;

			uniform float uTime; uniform vec2 uWind; uniform vec3 uColor; 
			float h2( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }
			float n2( vec2 p ) { vec2 i = floor( p ), f = fract( p ); vec2 u = f * f * ( 3.0 - 2.0 * f );
				return mix( mix( h2( i ), h2( i + vec2( 1, 0 ) ), u.x ), mix( h2( i + vec2( 0, 1 ) ), h2( i + vec2( 1, 1 ) ), u.x ), u.y ); }
			void fragment(){vec2 vUv=UV;vec3 vW=VERTEX*vec3(-1.0,1.0,1.0);vec3 cameraPosition=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);
				// 沿风向拉长的噪声：顺风方向频率低、横风方向高 → 一缕一缕的
				vec2 dir = uWind, side = vec2( - dir.y, dir.x );
				vec2 q = vec2( dot( vW.xz, dir ) * 0.08 - uTime * 1.1, dot( vW.xz, side ) * 0.55 );
				float n = n2( q ) * 0.6 + n2( q * 2.3 + vec2( - uTime * 0.8, 1.7 ) ) * 0.4;
				float a = smoothstep( 0.52, 0.85, n );
				float edge = smoothstep( 0.0, 0.25, vUv.x ) * smoothstep( 1.0, 0.75, vUv.x ) * smoothstep( 0.0, 0.35, vUv.y ) * smoothstep( 1.0, 0.65, vUv.y );
				float dist = length( vW - cameraPosition );
				ALBEDO=uColor*1.05;ALPHA=a*edge*0.2*smoothstep(2.0,8.0,dist);
			}