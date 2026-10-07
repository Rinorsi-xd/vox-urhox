// Ported from Vox/three/src/scene/hangarFx.js: backdropMaterial
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, cull_front, fog_disabled;
uniform float hangar_time = 0.0;


			 
			float h1( float x ) { return fract( sin( x * 127.1 ) * 43758.5453 ); }
			float h2( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }
			float h3( vec3 p ) { return fract( sin( dot( p, vec3( 127.1, 311.7, 74.7 ) ) ) * 43758.5453 ); }
			float n1( float x ) { float i = floor( x ), f = fract( x ); f = f * f * ( 3.0 - 2.0 * f ); return mix( h1( i ), h1( i + 1.0 ), f ); }
			float n3( vec3 p ) {
				vec3 i = floor( p ), f = fract( p ); f = f * f * ( 3.0 - 2.0 * f );
				return mix( mix( mix( h3( i ), h3( i + vec3( 1, 0, 0 ) ), f.x ), mix( h3( i + vec3( 0, 1, 0 ) ), h3( i + vec3( 1, 1, 0 ) ), f.x ), f.y ),
					mix( mix( h3( i + vec3( 0, 0, 1 ) ), h3( i + vec3( 1, 0, 1 ) ), f.x ), mix( h3( i + vec3( 0, 1, 1 ) ), h3( i + vec3( 1, 1, 1 ) ), f.x ), f.y ), f.z );
			}
			float fbm( vec3 p ) { float a = 0.5, s = 0.0; for ( int i = 0; i < 5; i ++ ) { s += a * n3( p ); p = p * 2.03 + 1.7; a *= 0.5; } return s; }
			const vec3 BLUE = vec3( 0.25, 0.62, 1.0 );
const vec3 WARM = vec3( 1.0, 0.55, 0.22 );
			const vec3 SUN = vec3( - 0.86, 0.34, - 0.24 ); // 太阳方向（左侧偏前、偏上，未归一化）：门口看出去太阳在左边，眩光斜着扫进画面
			// 射线与球求交：返回近交点距离，没打到返回 -1
			float sphere( vec3 ro, vec3 rd, vec3 c, float r ) {
				vec3 oc = ro - c; float b = dot( oc, rd ), q = dot( oc, oc ) - r * r, h = b * b - q;
				return h < 0.0 ? (0.0 - 1.0) : - b - sqrt( h );
			}
			vec3 space( vec3 rd ) {
				float el = asin( clamp( rd.y, - 1.0, 1.0 ) ), az = atan( rd.x, - rd.z );
				vec3 sun = normalize( SUN );
				vec3 col = mix( vec3( 0.012, 0.02, 0.045 ), vec3( 0.004, 0.006, 0.016 ), smoothstep( - 0.2, 0.9, el ) );
				// 星云：两团慢慢飘动的云，一团电光蓝、一团暖橙，中间有暗带
				vec3 q = rd * 2.2 + vec3( hangar_time * 0.004, 0.0, hangar_time * 0.002 );
				float neb = fbm( q );
				float m1 = smoothstep( 0.45, 0.85, neb ) * smoothstep( 0.9, 0.2, abs( el - 0.45 + 0.25 * sin( az * 1.2 ) ) );
				float m2 = smoothstep( 0.5, 0.9, fbm( q * 1.3 + 4.0 ) ) * smoothstep( 0.7, 0.0, length( vec2( az - 0.65, el - 0.35 ) ) );
				col += BLUE * m1 * 0.16 + vec3( 0.9, 0.36, 0.2 ) * m2 * 0.12;
				col *= 1.0 - 0.6 * smoothstep( 0.55, 0.75, fbm( q * 2.6 + 9.0 ) ) * m1;
				// 星星：两层，亮的会闪
				for ( int k = 0; k < 2; k ++ ) {
					float sc = k == 0 ? 180.0 : 420.0;
					vec2 sg = vec2( az, el ) * sc, si = floor( sg );
					float s = h2( si + float( k ) * 31.0 );
					vec2 sf = fract( sg ) - 0.5 - ( vec2( h2( si + 2.0 ), h2( si + 5.0 ) ) - 0.5 ) * 0.6;
					float tw = k == 0 ? 0.55 + 0.45 * sin( hangar_time * ( 1.5 + s * 3.0 ) + s * 90.0 ) : 1.0;
					col += mix( vec3( 0.75, 0.85, 1.0 ), vec3( 1.0, 0.85, 0.7 ), h2( si + 9.0 ) ) * step( k == 0 ? 0.996 : 0.985, s ) * smoothstep( 0.35, 0.0, length( sf ) ) * tw * ( k == 0 ? 2.4 : 0.7 );
				}
				// 太阳 + 眩光（横向一道光芒）
				float sd = max( dot( rd, sun ), 0.0 );
				col += vec3( 1.0, 0.9, 0.75 ) * ( pow( sd, 4000.0 ) * 30.0 + pow( sd, 300.0 ) * 1.2 + pow( sd, 12.0 ) * 0.12 );
				vec2 so = vec2( az - atan( sun.x, - sun.z ), el - asin( sun.y ) );
				col += vec3( 1.0, 0.75, 0.5 ) * exp( - abs( so.y ) * 260.0 ) * exp( - abs( so.x ) * 3.5 ) * 0.5;
				// 带环的气态巨星（右上方），云带慢慢流动
				vec2 pc = vec2( az - 0.55, el - 0.42 );
				float pr = 0.17, pd = length( pc ) / pr;
				if ( pd < 1.0 ) {
					vec3 pn = vec3( pc / pr, sqrt( 1.0 - pd * pd ) );
					float lit = clamp( dot( pn, normalize( vec3( - 0.8, 0.2, 0.55 ) ) ), 0.0, 1.0 );
					float bands = n1( pn.y * 10.0 + 2.0 * n1( pn.x * 4.0 + pn.y * 3.0 + hangar_time * 0.05 ) );
					vec3 pcol = mix( vec3( 0.72, 0.5, 0.32 ), vec3( 0.95, 0.85, 0.7 ), bands );
					col = pcol * ( 0.02 + lit * 1.1 ) + vec3( 1.0, 0.6, 0.3 ) * pow( 1.0 - pn.z, 3.0 ) * 0.4 * lit;
				} else col += vec3( 1.0, 0.65, 0.4 ) * exp( - ( pd - 1.0 ) * 10.0 ) * 0.08;
				vec2 rp = mat2(vec2(cos(0.3),-sin(0.3)),vec2(sin(0.3),cos(0.3))) * pc;
				float re = length( vec2( rp.x, rp.y * 4.5 ) ) / pr;
				float ringM = smoothstep( 1.3, 1.36, re ) * ( 1.0 - smoothstep( 2.0, 2.06, re ) ) * ( 0.5 + 0.5 * n1( re * 34.0 ) );
				float front = min( 1.0, step( 0.0, - rp.y ) + step( 1.0, pd ) );
				col = mix( col, vec3( 0.85, 0.78, 0.68 ), ringM * front * 0.6 );
				// 小卫星：沿一条斜轨道慢慢走（约 4 分钟一圈），按太阳方向画出月相
				float ma = hangar_time * 0.026;
				vec2 mc = vec2( az - ( - 0.2 + 0.9 * cos( ma ) ), el - ( 0.32 + 0.16 * sin( ma ) ) );
				float md = length( mc ) / 0.03;
				if ( md < 1.0 ) col = vec3( 0.7, 0.72, 0.76 ) * ( 0.03 + 0.97 * clamp( dot( vec3( mc / 0.03, sqrt( 1.0 - md * md ) ), normalize( vec3( - 0.7, 0.3, 0.6 ) ) ), 0.0, 1.0 ) );
				// 远处的环形空间站：一个倾斜的光环慢慢转，环上一圈灯
				vec2 st = vec2( az + 0.75, el - 0.2 );
				vec2 sr = vec2( st.x, st.y * 3.2 );
				float rr = length( sr );
				float ringS = exp( - pow( abs( ( rr - 0.07 ) * 260.0 ), 2.0 ) );
				float ang = atan( sr.y, sr.x ) + hangar_time * 0.15;
				float lamps = step( 0.8, fract( ang * 12.0 / 6.2832 ) );
				col += vec3( 0.55, 0.6, 0.7 ) * ringS * 0.35 * ( 0.4 + 0.6 * smoothstep( - 0.02, 0.02, st.y ) ) + mix( BLUE, WARM, step( 0.5, fract( ang * 6.0 / 6.2832 ) ) ) * ringS * lamps * 1.2;
				col += vec3( 0.6, 0.65, 0.75 ) * exp( - length( st * vec2( 1.0, 3.2 ) ) * 120.0 ) * 0.8; // 中间的轮毂
				// 飞船：几艘拖着尾焰横穿天空
				for ( int i = 0; i < 5; i ++ ) {
					float fi = float( i );
					float sp = 0.01 + 0.012 * h1( fi );
					float dir = h1( fi * 4.0 ) > 0.5 ? 1.0 : (0.0 - 1.0);
					float ax = dir * ( - 1.5 + mod( hangar_time * sp + h1( fi * 7.0 ) * 3.0, 3.0 ) );
					float ey = 0.06 + 0.3 * h1( fi * 3.0 + 1.0 );
					vec2 d = vec2( az - ax, ( el - ey ) * 1.5 );
					float head = exp( - length( d ) * 900.0 );
					float trail = exp( - abs( d.y ) * 1500.0 ) * exp( - max( 0.0, - d.x * dir ) * 40.0 ) * step( 0.0, - d.x * dir );
					col += mix( WARM, BLUE, step( 0.5, h1( fi * 5.0 ) ) ) * ( head * 3.0 + trail * 0.6 );
				}
				// 流星：每 7 秒左右一颗，从右上往左下划过
				{
					float k = floor( hangar_time / 7.0 ), ph = fract( hangar_time / 7.0 );
					vec2 p0 = vec2( - 0.6 + 1.4 * h1( k ), 0.35 + 0.35 * h1( k + 3.0 ) );
					vec2 dv = normalize( vec2( - 0.8, - 0.35 ) );
					vec2 hp = p0 + dv * ph * 0.9;
					vec2 rel = vec2( az, el ) - hp;
					float along = dot( rel, dv ), across = abs( dot( rel, vec2( - dv.y, dv.x ) ) );
					float met = exp( - across * 900.0 ) * smoothstep( - 0.12, 0.0, along ) * step( along, 0.0 ) * smoothstep( 0.0, 0.1, ph ) * smoothstep( 0.35, 0.2, ph );
					col += vec3( 0.85, 0.92, 1.0 ) * met * 2.5;
				}
				return col;
			}
			void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec2 vUv = vec2(UV.x,1.0-UV.y);
 vec3 vW = vec3(-VERTEX.x,VERTEX.yz);
 vec3 vN = NORMAL;
 vec3 vV = CAMERA_POSITION_WORLD - VERTEX;
				vec3 ro = vec3(-CAMERA_POSITION_WORLD.x, CAMERA_POSITION_WORLD.yz), rd = normalize( vW - vec3(-CAMERA_POSITION_WORLD.x, CAMERA_POSITION_WORLD.yz) );
				vec3 sun = normalize( SUN );
				// 脚下的星球：球心在门外远处的下方
				vec3 pc = vec3( 0.0, - 1500.0, - 2400.0 ); // 顶端（弧形地平线）比视平线高约 5°
				float R = 1700.0;
				float t = sphere( ro, rd, pc, R );
				vec3 col;
				if ( t > 0.0 ) {
					vec3 n = normalize( ro + rd * t - pc );
					// 星球自转：绕自身 Y 轴慢慢转，云带跟着走
					float a = hangar_time * 0.006;
					vec3 m = vec3( n.x * cos( a ) - n.z * sin( a ), n.y, n.x * sin( a ) + n.z * cos( a ) );
					float land = smoothstep( 0.52, 0.56, fbm( m * 3.0 ) );
					float cloud = smoothstep( 0.5, 0.75, fbm( m * 5.0 + vec3( hangar_time * 0.01, 0.0, 0.0 ) ) );
					vec3 sea = vec3( 0.02, 0.07, 0.16 ), ground = vec3( 0.16, 0.13, 0.1 );
					vec3 surf = mix( mix( sea, ground, land ), vec3( 0.85, 0.88, 0.92 ), cloud * 0.85 );
					float dl = dot( n, sun );
					float day = smoothstep( - 0.05, 0.25, dl );
					col = surf * ( 0.02 + 1.2 * day );
					col += WARM * exp( - abs( dl - 0.02 ) * 18.0 ) * 0.18; // 晨昏线一道暖光
					float rim = pow( 1.0 - max( dot( n, - rd ), 0.0 ), 3.0 );
					col = mix( col, BLUE * ( 0.25 + 0.9 * day ), rim * 0.75 ); // 边缘大气
				} else {
					col = space( rd );
					// 星球外沿的大气光晕：离球面越近越亮，向阳一侧更亮
					vec3 oc = ro - pc;
					float b = dot( oc, rd );
					float dmin = sqrt( max( dot( oc, oc ) - b * b, 0.0 ) ) - R;
					if ( b < 0.0 ) {
						float side = 0.35 + 0.65 * smoothstep( - 0.6, 0.6, dot( normalize( ro + rd * - b - pc ), sun ) );
						col += BLUE * exp( - dmin / 28.0 ) * 0.9 * side + vec3( 0.7, 0.85, 1.0 ) * exp( - dmin / 6.0 ) * 0.5 * side;
					}
				}
				ALBEDO = col;
			}