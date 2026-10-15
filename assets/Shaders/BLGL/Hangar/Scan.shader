// Ported from Vox/three/src/scene/hangarFx.js: scanMaterial
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, cull_disabled, fog_disabled, blend_premul_alpha, depth_draw_never;
uniform float hangar_time = 0.0;
uniform float uStrength = 0.0;

			  
			void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec2 vUv = vec2(UV.x,1.0-UV.y);
 vec3 vW = vec3(-VERTEX.x,VERTEX.yz);
 vec3 vN = NORMAL;
 vec3 vV = CAMERA_POSITION_WORLD - VERTEX;
				vec2 e = min( vUv, 1.0 - vUv );
				float frame = 1.0 - smoothstep( 0.0, 0.012, min( e.x, e.y * 0.6 ) );
				float lines = step( 0.6, fract( vUv.y * 60.0 - hangar_time * 3.0 ) ) * 0.08;
				float a = ( frame * 0.9 + 0.035 + lines ) * smoothstep( 0.0, 0.08, e.y ) * uStrength;
				ALBEDO = vec3( 0.92, 0.94, 0.97 ) * a;
 ALPHA = 0.0;
			}