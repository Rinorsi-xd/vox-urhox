shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,fog_disabled;

uniform vec3 uColor;
uniform float uTime;
uniform float uHP=1.0;      // 0..1
uniform float uDown=0.0;    // 0 = 完好，1 = 已击穿（溶解完）
uniform float uRaise=1.0;   // 重新升起的进度 0..1（1 = 升完）
uniform float uHeight;
uniform vec4 uHits[ 8 ]; // xyz = 位置，w = 开始时间（< 0 不用）

varying vec3 sourceScaledNormal;
varying vec3 vL;
vec3 sH3( vec3 p ) { p = vec3( dot( p, vec3( 127.1, 311.7, 74.7 ) ), dot( p, vec3( 269.5, 183.3, 246.1 ) ), dot( p, vec3( 113.5, 271.9, 124.6 ) ) ); return fract( sin( p ) * 43758.5453 ); }
float sN( vec3 p ) { vec3 i = floor( p ), f = fract( p ); f = f * f * ( 3.0 - 2.0 * f );
	return mix( mix( mix( sH3( i ).x, sH3( i + vec3( 1, 0, 0 ) ).x, f.x ), mix( sH3( i + vec3( 0, 1, 0 ) ).x, sH3( i + vec3( 1, 1, 0 ) ).x, f.x ), f.y ),
		mix( mix( sH3( i + vec3( 0, 0, 1 ) ).x, sH3( i + vec3( 1, 0, 1 ) ).x, f.x ), mix( sH3( i + vec3( 0, 1, 1 ) ).x, sH3( i + vec3( 1, 1, 1 ) ).x, f.x ), f.y ), f.z ); }
// 维诺图：到格子边界的距离（Inigo Quilez 的两遍法，第二遍只看相邻一圈）
float voronoiEdge( vec3 x ) {
	vec3 p = floor( x ), f = fract( x );
	vec3 mb = vec3( 0.0 ), mr = vec3( 0.0 ); float md = 8.0;
	for ( int k = - 1; k <= 1; k ++ ) for ( int j = - 1; j <= 1; j ++ ) for ( int i = - 1; i <= 1; i ++ ) {
		vec3 b = vec3( float( i ), float( j ), float( k ) );
		vec3 r = b + sH3( p + b ) - f;
		float d = dot( r, r );
		if ( d < md ) { md = d; mr = r; mb = b; }
	}
	md = 8.0;
	for ( int k = - 1; k <= 1; k ++ ) for ( int j = - 1; j <= 1; j ++ ) for ( int i = - 1; i <= 1; i ++ ) {
		vec3 b = mb + vec3( float( i ), float( j ), float( k ) );
		vec3 r = b + sH3( p + b ) - f;
		vec3 dr = r - mr;
		if ( dot( dr, dr ) > 1e-5 ) md = min( md, dot( 0.5 * ( mr + r ), normalize( dr ) ) );
	}
	return md;
}
void fragment() {
vec3 vW=VERTEX*vec3(-1.0,1.0,1.0);vec3 vN=sourceScaledNormal*vec3(-1.0,1.0,1.0);vec3 cameraPosition=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);
	vec3 V = normalize( cameraPosition - vW );
	vec3 N = normalize( vN ) * ( FRONT_FACING ? 1.0 : - 1.0 );
	float ndv = abs( dot( N, V ) );
	float fres = pow( 1.0 - ndv, 3.0 );
	float y01 = clamp( vL.y, 0.0, 1.0 ); // 0 罩底 … 1 罩顶
	// 描边：维诺图边界，宽度按像素抗锯齿
	vec3 q = vW * 0.16;
	float e = voronoiEdge( q );
	float aa = fwidth( e ) * 1.2;
	float edge = 1.0 - smoothstep( 0.008, 0.028 + aa, e );
	edge *= clamp( 0.03 / max( aa, 0.03 ), 0.3, 1.0 ); // 远处格线比像素还细：按覆盖率变淡
	// 往上流的能量带
	float flow = smoothstep( 0.9, 1.0, sin( vW.y * 0.7 - uTime * 2.2 + sN( q * 1.3 ) * 2.0 ) ) * 0.3;
	// 受击波纹：从命中点往外扩的一圈亮环，边上的格线也一起亮
	float ripple = 0.0, flash = 0.0;
	for ( int i = 0; i < 8; i ++ ) {
		vec4 h = uHits[ i ];
		float age = uTime - h.w;
		if ( h.w < 0.0 || age > 1.6 || age < 0.0 ) continue;
		float d = length( vW - h.xyz );
		float R = age * 26.0;
		float ring = exp( - pow( ( d - R ) / 1.6, 2.0 ) ) * ( 1.0 - age / 1.6 );
		ripple += ring;
		flash += exp( - d * 0.35 ) * exp( - age * 6.0 ) * 2.5;
	}
	// 血量低：闪烁 + 裂纹（用更大一格的维诺图）
	float low = 1.0 - smoothstep( 0.15, 0.5, uHP );
	float crack = low * ( 1.0 - smoothstep( 0.0, 0.05 + aa, voronoiEdge( vW * 0.05 + 3.1 ) ) );
	float flick = 1.0 - low * 0.5 * step( 0.6, sN( vec3( uTime * 9.0, 0.0, 0.0 ) ) );
	// 击穿：从顶上往下溶解（边上一圈亮）；重新升起：从底部扫上去
	float dn = sN( vW * 0.35 ) * 0.25;
	float cut = uDown * 1.3 - ( 1.0 - y01 ) - dn;           // > 0 的地方已经溶掉
	float alive = 1.0 - smoothstep( - 0.02, 0.02, cut );
	float burn = exp( - pow( cut / 0.04, 2.0 ) ) * step( 0.001, uDown ) * ( 1.0 - uDown * 0.6 );
	float rise = uRaise < 1.0 ? smoothstep( uRaise + 0.02, uRaise - 0.02, y01 ) : 1.0;
	float scan = uRaise < 1.0 ? exp( - pow( ( y01 - uRaise ) / 0.025, 2.0 ) ) * 2.5 : 0.0;
	float k = ( 0.03 + edge * ( 0.38 + ripple * 1.5 ) + fres * 0.5 + flow * ( 0.08 + edge * 0.9 ) + ripple * 0.35 + flash + crack * 1.4 ) * flick * alive * rise + burn * 3.0 + scan;
	// 远处淡一点（和雾差不多）
	k *= exp( - length( vW - cameraPosition ) * 0.0011 );
	vec3 c = uColor * k;
	c += vec3( 1.0 ) * ( flash * 0.25 + burn * 0.6 ) * alive;
	ALBEDO=c;ALPHA=1.0;
}
void vertex(){vL=VERTEX;sourceScaledNormal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
