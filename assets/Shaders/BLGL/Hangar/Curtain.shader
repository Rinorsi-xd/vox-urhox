// Ported from Vox/three/src/scene/hangarFx.js: curtainMaterial
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, cull_disabled, fog_disabled, blend_premul_alpha, depth_draw_never;
uniform float hangar_time = 0.0;


			    
			void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec2 vUv = vec2(UV.x,1.0-UV.y);
 vec3 vW = vec3(-VERTEX.x,VERTEX.yz);
 vec3 vN = NORMAL;
 vec3 vV = CAMERA_POSITION_WORLD - VERTEX;
				float u = vW.x / 0.6;
				float d = abs( fract( u ) - 0.5 ) / max( fwidth( u ), 1e-4 );
				float heavy = step( 0.75, fract( floor( u ) / 4.0 ) );
				float hangarLine = ( 1.0 - clamp( d - mix( 0.6, 1.4, heavy ), 0.0, 1.0 ) ) * mix( 0.55, 1.0, heavy );
				float sweep = exp( - pow( abs( vW.y - ( mod( hangar_time * 2.4, 34.0 ) - 6.0 ) ), 2.0 ) * 0.25 );
				float facing = abs( dot( normalize( vN ), normalize( vV ) ) );
				float edge = smoothstep( 0.0, 0.04, vUv.x ) * smoothstep( 0.0, 0.04, 1.0 - vUv.x ) * smoothstep( 0.0, 0.05, 1.0 - vUv.y );
				float a = ( hangarLine * ( 0.07 + sweep * 0.3 ) + sweep * 0.02 + 0.004 ) * mix( 2.2, 0.7, facing ) * edge;
				a *= 0.8 + 0.2 * sin( vW.y * 0.9 - hangar_time * 2.0 );
				ALBEDO = vec3( 0.18, 0.66, 1.0 ) * a;
 ALPHA = 0.0;
			}