// Ported from Vox/three/src/scene/hangarFx.js: beamMaterial
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, cull_disabled, fog_disabled, blend_premul_alpha, depth_draw_never;
uniform float hangar_time = 0.0;
uniform vec3 uColor = vec3(1.0);
uniform float uStrength = 0.012;
uniform float uPow = 2.2;

			     
			void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec2 vUv = vec2(UV.x,1.0-UV.y);
 vec3 vW = vec3(-VERTEX.x,VERTEX.yz);
 vec3 vN = NORMAL;
 vec3 vV = CAMERA_POSITION_WORLD - VERTEX;
				float side = smoothstep( 0.0, 0.25, vUv.x ) * smoothstep( 0.0, 0.25, 1.0 - vUv.x );
				float a = pow( max(vUv.y, 0.0), uPow ) * side * uStrength * ( 0.9 + 0.1 * sin( hangar_time * 3.0 + vUv.y * 9.0 ) );
				a *= smoothstep( 0.5, 3.0, length( vV ) );
				ALBEDO = uColor * a;
 ALPHA = 0.0;
			}