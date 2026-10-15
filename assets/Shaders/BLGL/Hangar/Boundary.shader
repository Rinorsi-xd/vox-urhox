// Ported from Vox/three/src/scene/hangarFx.js: boundaryMaterial
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, cull_disabled, fog_disabled, blend_premul_alpha, depth_draw_never;
uniform float hangar_time = 0.0;
uniform vec2 uCursor = vec2(0.0);
uniform float uCursorOn = 0.0;
uniform float uFlash = 0.0;

			     
			void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec2 vUv = vec2(UV.x,1.0-UV.y);
 vec3 vW = vec3(-VERTEX.x,VERTEX.yz);
 vec3 vN = NORMAL;
 vec3 vV = CAMERA_POSITION_WORLD - VERTEX;
				float near = exp( - length( vW.xz - uCursor ) / 3.5 ) * uCursorOn;
				float g = pow( max(1.0 - vUv.y, 0.0), 2.2 );
				float lines = 0.6 + 0.4 * step( 0.5, fract( vW.y * 6.0 - hangar_time * 0.8 ) );
				float a = g * ( 0.03 + near * 0.55 + uFlash * 0.25 ) * lines;
				ALBEDO = mix( vec3( 0.72, 0.76, 0.82 ), vec3( 0.18, 0.66, 1.0 ), clamp( near * 3.0, 0.0, 1.0 ) ) * a;
 ALPHA = 0.0;
			}