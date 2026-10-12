// Ported from Vox/three/src/scene/hangarFx.js: holoMaterial
shader_type spatial;
#include "../lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, cull_disabled, fog_disabled, blend_premul_alpha, depth_draw_never;
uniform float hangar_time = 0.0;
uniform sampler2D uMap : source_color, filter_linear_mipmap, repeat_disable;
uniform float uAlpha = 1.15;
#include "Canvas.shaderinc"

			   
			void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
 vec2 vUv = vec2(UV.x,1.0-UV.y);
 vec3 vW = vec3(-VERTEX.x,VERTEX.yz);
 vec3 vN = NORMAL;
 vec3 vV = CAMERA_POSITION_WORLD - VERTEX;
				vec2 uv = vUv;
				float j = step( 0.975, fract( sin( floor( hangar_time * 8.0 ) * 12.9898 ) * 43758.5453 ) );
				uv.x += j * 0.006 * sin( uv.y * 70.0 + hangar_time * 40.0 );
				vec3 c = texture( uMap, vec2(uv.x,1.0-uv.y) ).rgb;
                if (canvas_enabled > 0.5) c = hangar_canvas(vec2(uv.x,1.0-uv.y)).rgb;
				float scan = 0.88 + 0.12 * sin( uv.y * 1100.0 );
				float band = 1.0 + 0.35 * exp( - pow( abs( ( fract( uv.y * 0.6 - hangar_time * 0.12 ) - 0.5 ) * 12.0 ), 2.0 ) );
				float edge = smoothstep( 0.0, 0.015, uv.x ) * smoothstep( 0.0, 0.015, 1.0 - uv.x ) * smoothstep( 0.0, 0.02, uv.y ) * smoothstep( 0.0, 0.02, 1.0 - uv.y );
				// 背面只留一层淡光，不显示（左右反过来的）文字
                // Authored +Z plane normal identifies the readable side on both
                // DX and Web rasterizers, including reflected cameras.
                if ( dot(NORMAL, CAMERA_POSITION_WORLD - VERTEX) <= 0.0 ) c = vec3( 0.01, 0.03, 0.05 );
				ALBEDO = c * scan * band * edge * uAlpha;
 ALPHA = 0.0;
			}
