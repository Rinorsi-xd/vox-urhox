shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;

uniform vec3 uColor; uniform vec3 uSunCol=vec3(.8963,.5776,.2961); uniform vec3 uSun; uniform float uTime;

float h2( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }
float n2( vec2 p ) { vec2 i = floor( p ), f = fract( p ); vec2 u = f * f * ( 3.0 - 2.0 * f );
	return mix( mix( h2( i ), h2( i + vec2( 1, 0 ) ), u.x ), mix( h2( i + vec2( 0, 1 ) ), h2( i + vec2( 1, 1 ) ), u.x ), u.y ); }
void fragment() {
vec2 vUv=UV;vec4 vLook=vec4(COLOR.a,COLOR.r,COLOR.g,0.0);float vFade=1.0;
	vec2 q = vUv - 0.5;
	float r = length( q ) * 2.0;
	vec2 o = vec2( vLook.y * 17.0, vLook.y * 9.0 ) + vec2( uTime * 0.03, - uTime * 0.05 );
	float n = n2( vUv * 3.0 + o ) * 0.6 + n2( vUv * 7.0 - o * 1.7 ) * 0.4;
	float a = smoothstep( 1.0, 0.25, r + ( n - 0.5 ) * 0.7 ) * vLook.x * vFade;
	if ( a < 0.003 ) discard;
	// 朝太阳的一侧亮一点（烟团的上缘、迎光面）
	float lit = 0.55 + 0.45 * clamp( dot( normalize( vec3( q.x, q.y + 0.25, 0.4 ) ), vec3( 0.0, 1.0, 0.3 ) ), 0.0, 1.0 );
	vec3 col = mix( uColor, uSunCol, lit * 0.35 ) * vLook.z * ( 0.8 + 0.4 * n );
	ALBEDO=col;ALPHA=a;
}