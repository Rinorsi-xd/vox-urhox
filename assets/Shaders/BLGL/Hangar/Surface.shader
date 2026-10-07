shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, cull_back;
#include "../lib/VoxHemi.shaderinc"
uniform vec4 base_color = vec4(0.5,0.5,0.5,1.0);
uniform vec3 emission_color = vec3(0.0);
uniform float emission_strength = 0.0;
uniform float roughness_value = 0.5;
uniform float metallic_value = 0.0;
uniform float panel_on = 0.0;
uniform vec2 uPanel = vec2(1.0);
uniform float uSeam = 0.02;
uniform float uVary = 0.05;
uniform float uPulse = 0.0;
uniform float uBlink = 0.0;
uniform float hangar_time = 0.0;

	
	
	float hHash( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }
	float hNoise( vec2 p ) {
		vec2 i = floor( p ), f = fract( p ); f = f * f * ( 3.0 - 2.0 * f );
		return mix( mix( hHash( i ), hHash( i + vec2( 1, 0 ) ), f.x ), mix( hHash( i + vec2( 0, 1 ) ), hHash( i + vec2( 1, 1 ) ), f.x ), f.y );
	}
	// 按法线主方向选投影平面
	vec2 hPlane( vec3 w, vec3 n ) { vec3 a = abs( n ); return a.y > max( a.x, a.z ) ? w.xz : ( a.x > a.z ? w.zy : w.xy ); }
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec3 w=vec3(-VERTEX.x,VERTEX.yz);
 vec3 n=vec3(-NORMAL.x,NORMAL.yz);
 ALBEDO=base_color.rgb; ROUGHNESS=roughness_value; METALLIC=metallic_value;
 if(panel_on>0.5) {
vec2 hp = hPlane( w, n );
				vec2 hg = hp / uPanel;
				vec2 hid = floor( hg );
				vec2 hf = fract( hg );
				vec2 hde = min( hf, 1.0 - hf ) * uPanel;
				float he = min( hde.x, hde.y );
				float haa = length( fwidth( hp ) ) + 1e-4;
				float hSeam = 1.0 - smoothstep( uSeam, uSeam + haa * 1.2, he );
				float hRnd = hHash( hid + floor( n.xz * 3.0 + 0.5 ) * 17.0 );
				float hGrit = hNoise( hp * 5.0 );
				// 面板缝内侧一道细亮边（假倒角）
				float hBevel = smoothstep( uSeam, uSeam + 0.02, he ) * ( 1.0 - smoothstep( uSeam + 0.02, uSeam + 0.07, he ) );
				ALBEDO *= ( 1.0 - uVary + 2.0 * uVary * hRnd ) * ( 1.0 - hSeam * 0.6 ) * ( 0.96 + hGrit * 0.08 );
				ALBEDO += hBevel * 0.025;
				float hRough = ( hRnd - 0.5 ) * 0.7 + ( hGrit - 0.5 ) * 0.5 + hSeam * 0.8;
 ROUGHNESS=clamp(ROUGHNESS+hRough*0.18,0.04,1.0);
 }
 EMISSION=emission_color*emission_strength;
EMISSION *= 1.0 + uPulse * sin( hangar_time * 1.6 + dot( w, vec3( 0.21, 0.13, 0.17 ) ) );
				if ( uBlink > 0.0 ) EMISSION *= 0.08 + 0.92 * step( 0.55, fract( hangar_time * uBlink + hHash( floor( w.xz * 0.5 ) ) ) );
 EMISSION+=vox_hemi(ALBEDO,METALLIC,NORMAL);
}
