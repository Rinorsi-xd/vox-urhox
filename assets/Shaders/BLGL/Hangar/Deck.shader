shader_type spatial;
render_mode shading_model_pbr, cull_back;
#include "../lib/VoxHemi.shaderinc"
uniform sampler2D refl_mip1 : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D refl_mip2 : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D refl_mip3 : hint_default_black, filter_linear, repeat_disable;
uniform mat4 refl_matrix;
uniform float refl_strength=0.28;
uniform float refl_blur=4.0;
uniform float refl_distort=0.003;
uniform float refl_flip_y=0.0;
uniform vec2 uEnvMin=vec2(-15.25,-20.25);
uniform vec2 uEnvMax=vec2(15.25,20.25);
uniform float uGrid=0.18;
uniform float uFrame=1.0;
uniform vec2 uCursor=vec2(0.0);
uniform float uCursorOn=0.0;
uniform float uRingR=6.0;
uniform vec3 uScan=vec3(0.0);
uniform float uFlash=0.0;
float refl_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec3 refl_sample(vec2 uv,float lod) {
    if(lod<2.0) return mix(texture(refl_mip1,uv).rgb,texture(refl_mip2,uv).rgb,clamp(lod-1.0,0.0,1.0));
    return mix(texture(refl_mip2,uv).rgb,texture(refl_mip3,uv).rgb,clamp(lod-2.0,0.0,1.0));
}
void fragment() {
 ALBEDO=vec3(0.03434,0.03689,0.04519); ROUGHNESS=0.38; METALLIC=0.3;
 CLEARCOAT=0.55; CLEARCOAT_ROUGHNESS=0.24; AO=0.6;
 float rgh=ROUGHNESS; vec3 emit=vec3(0.0);
    if (refl_strength > 0.0) {
        vec4 clip = refl_matrix * vec4(VERTEX,1.0);
        vec2 suv = clip.xy / clip.w * vec2(0.5,-0.5) + vec2(0.5);
        if (refl_flip_y > 0.5) {
            suv.y = 1.0 - suv.y;
        }
        float lod = rgh * refl_blur;
        float ang = refl_hash(floor(vec2(-VERTEX.x,VERTEX.z)*40.0))*6.2831;
        vec2 jit = vec2(cos(ang),sin(ang))*refl_distort*rgh;
        vec3 refl = refl_sample(suv+jit,lod)*0.4;
        refl += refl_sample(suv+vec2(jit.y,-jit.x)*1.7,lod+0.6)*0.3;
        refl += refl_sample(suv-jit*1.3,lod+1.0)*0.3;
        refl = refl / (1.0 + max(max(refl.r, refl.g), refl.b) * 0.45);
        vec3 view_dir = normalize(CAMERA_POSITION_WORLD - VERTEX);
        float ndv = clamp(dot(normalize(NORMAL), view_dir), 0.0, 1.0);
        float fres = 0.22 + 0.78 * pow(1.0 - ndv, 4.0);
        emit += refl * refl_strength * fres * (1.0 - rgh * 0.55);
    }

 EMISSION=emit;
vec2 w = vec2(-VERTEX.x,VERTEX.z);
				float vd = length( (CAMERA_POSITION_WORLD-VERTEX) );
				vec3 energy = vec3( 0.18, 0.66, 1.0 ), brand = vec3( 1.0, 0.42, 0.08 ), hangarLine = vec3( 0.43, 0.68, 0.92 );
				// 网格线：格边在 (n ± 0.5) × 0.5 米；大格 5×5，中间那一列居中（对称轴在大格中间）
				vec2 g1 = ( w - 0.25 ) / 0.5, g5 = ( w - 1.25 ) / 2.5;
				vec2 f1 = fwidth( g1 ), f5 = fwidth( g5 );
				vec2 d1 = ( 0.5 - abs( fract( g1 ) - 0.5 ) ) / max( f1, vec2( 1e-4 ) );
				vec2 d5 = ( 0.5 - abs( fract( g5 ) - 0.5 ) ) / max( f5, vec2( 1e-4 ) );
				float minor = ( 1.0 - clamp( min( d1.x, d1.y ) - 0.5, 0.0, 1.0 ) ) * ( 1.0 - smoothstep( 0.12, 0.35, max( f1.x, f1.y ) ) );
				float major = 1.0 - clamp( min( d5.x, d5.y ) - 0.8, 0.0, 1.0 );
				// Seam attenuation must reach direct highlights and reflected light too.
				float seam = 1.0 - major * 0.4;
				AO *= seam;
				AO_LIGHT_AFFECT = (1.0-seam)/max(1.0-AO,0.0001);
				EMISSION = (EMISSION+vox_hemi(ALBEDO,METALLIC,NORMAL))*seam;
				float inside = step( uEnvMin.x, w.x ) * step( w.x, uEnvMax.x ) * step( uEnvMin.y, w.y ) * step( w.y, uEnvMax.y );
				float fade = smoothstep( 60.0, 8.0, vd );
				EMISSION += hangarLine * ( minor * 0.022 + major * 0.06 ) * inside * fade * uGrid;
				// 对称轴（x = 0）：橙色虚线
				float ax = 1.0 - clamp( abs( w.x ) / max( fwidth( w.x ), 1e-4 ) - 1.0, 0.0, 1.0 );
				EMISSION += brand * ax * step( 0.5, fract( w.y ) ) * inside * fade * 0.45 * uGrid;
				// 建造区域边框：光标靠近时变亮
				vec2 de = min( abs( w - uEnvMin ), abs( w - uEnvMax ) );
				float onX = step( uEnvMin.y - 0.05, w.y ) * step( w.y, uEnvMax.y + 0.05 );
				float onZ = step( uEnvMin.x - 0.05, w.x ) * step( w.x, uEnvMax.x + 0.05 );
				vec2 fw = max( fwidth( w ), vec2( 1e-4 ) );
				float border = max( ( 1.0 - clamp( de.x / fw.x - 1.5, 0.0, 1.0 ) ) * onX, ( 1.0 - clamp( de.y / fw.y - 1.5, 0.0, 1.0 ) ) * onZ );
				float near = exp( - length( w - uCursor ) / 4.0 ) * uCursorOn;
				EMISSION += ( hangarLine * 0.5 + energy * near * 3.5 * uGrid ) * border * uFrame;
				// 转台：一道电光蓝亮环 + 外面一道细的白环（换车时闪一下）；不随 uGrid 变暗，主页上也看得见
				float r = length( w );
				float fr = max( fwidth( r ), 1e-4 );
				float ring = 1.0 - clamp( abs( r - uRingR ) / fr - 1.0, 0.0, 1.0 );
				float ring2 = 1.0 - clamp( abs( r - uRingR - 1.1 ) / fr - 0.5, 0.0, 1.0 );
				EMISSION += ( energy * ring * 1.1 + hangarLine * ring2 * 0.3 ) * fade * ( 1.0 + uFlash * 2.0 );
				// 扫描线（进入车库时扫过车身）：uScan = ( z, 半宽, 强度 )
				float sl = 1.0 - clamp( abs( w.y - uScan.x ) / fw.y - 2.0, 0.0, 1.0 );
				EMISSION += vec3( 0.95 ) * sl * step( abs( w.x ), uScan.y ) * uScan.z * 2.4;
}
