shader_type spatial;
render_mode shading_model_pbr, cull_back;
#define TERRAIN_FAR 1
float clamp01(float v){return clamp(v,0.0,1.0);}
#include "Fog.shaderinc"
#include "DirectLight.shaderinc"
float layerSat(int i){if(i==0)return 0.95;if(i==1)return 0.9;if(i==2)return 0.6;if(i==3)return 0.9;if(i==4)return 0.85;if(i==5)return 0.7;return 0.7;}
vec3 layerTint(int i){if(i==0)return vec3(1.1,1.02,0.9);if(i==1)return vec3(1,1,1);if(i==2)return vec3(1.14,1.06,0.97);if(i==3)return vec3(1.12,1.02,0.9);if(i==4)return vec3(1.06,0.98,0.9);if(i==5)return vec3(0.98,0.9,0.82);return vec3(0.98,0.9,0.82);}

uniform sampler2DArray tAlb;
uniform sampler2DArray tNra;



const float uMode=0.0;
uniform sampler2D tGround;
uniform float uGroundHalf=320.0;
uniform vec2 uBakeFade=vec2(52.0,66.0);




#if TERRAIN_FAR > 0

#endif
float tH( vec2 p ) { p = fract( p * vec2( 123.34, 456.21 ) ); p += dot( p, p + 45.32 ); return fract( p.x * p.y ); }
float tN( vec2 p ) { vec2 i = floor( p ), f = fract( p ); vec2 u = f * f * ( 3.0 - 2.0 * f );
	return mix( mix( tH( i ), tH( i + vec2( 1.0, 0.0 ) ), u.x ), mix( tH( i + vec2( 0.0, 1.0 ) ), tH( i + vec2( 1.0, 1.0 ) ), u.x ), u.y ); }
// 去重复采样：k 是低频噪声（0..1），按它换两组偏移交叉混合
// 导数在分支外算好传进来（分支里自动求导是未定义的）
// 远处（tLowQ = 1，离镜头 130 米以外）只采一次：远处颜色本来就往这一层的平均色靠，看不出平铺，省掉一半的贴图读取

void tSample( float tLowQ, float L, vec2 uv, vec2 dx, vec2 dy, float k, out vec4 alb, out vec4 nra ) {
	float l = k * 8.0, f = fract( l ), ia = floor( l );
	vec2 oa = sin( vec2( 3.0, 7.0 ) * ia ), ob = sin( vec2( 3.0, 7.0 ) * ( ia + 1.0 ) );
	if ( tLowQ > 0.5 ) { alb = textureGrad( tAlb, vec3( uv + oa, L ), dx, dy ); nra = textureGrad( tNra, vec3( uv + oa, L ), dx, dy ); return; }
	vec4 a1 = textureGrad( tAlb, vec3( uv + oa, L ), dx, dy ), a2 = textureGrad( tAlb, vec3( uv + ob, L ), dx, dy );
	vec4 n1 = textureGrad( tNra, vec3( uv + oa, L ), dx, dy ), n2 = textureGrad( tNra, vec3( uv + ob, L ), dx, dy );
	float t = smoothstep( 0.2, 0.8, f - 0.1 * dot( a1.rgb - a2.rgb, vec3( 1.0 ) ) );
	alb = mix( a1, a2, t ); nra = mix( n1, n2, t );
}
vec3 tGrade( vec3 c, int i ) { float l = dot( c, vec3( 0.2126, 0.7152, 0.0722 ) ); return mix( vec3( l ), c, layerSat(i) ) * layerTint(i); }
vec3 tDecodeN( vec4 nra ) { vec2 xy = nra.rg * 2.0 - 1.0; xy.y = - xy.y; return vec3( xy, sqrt( clamp01( 1.0 - dot( xy, xy ) ) ) ); }

void fragment(){
vec3 vTWPos=VERTEX*vec3(-1.0,1.0,1.0);vec3 sourceCamera=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);vec3 vTWNrm=NORMAL*vec3(-1.0,1.0,1.0);vec4 vW=COLOR;vec3 vLegacy=vec3(0.4);float vSun=UV2.x;

vec3 tP = vTWPos;
vec3 tNg = normalize( vTWNrm );
vec3 tDx = dFdx( tP ), tDy = dFdy( tP );
float tCam = length( tP - sourceCamera );
float tLowQ = step( 130.0, tCam );
float tMacro = tN( tP.xz * 0.011 ) * 0.6 + tN( tP.xz * 0.043 + 7.1 ) * 0.4;
float tRough = 0.9, tAO = 1.0;
vec3 tWN = tNg;
vec3 tCol;
if ( uMode > 0.5 ) {
	tCol = vLegacy;
} else {
	// 岩壁权重：坡度 + 噪声（陡到一定程度就是岩壁）；地势越高越容易露岩（山体是岩石和碎石坡，不是沙）
	float hk = smoothstep( 8.0, 32.0, tP.y );
	float wCliff = smoothstep( 0.83 + 0.11 * hk, 0.64 + 0.2 * hk, tNg.y + ( tMacro - 0.5 ) * 0.16 );
	// 远处去重复：颜色往这一层的平均色 × 大尺度明暗靠，法线往几何法线靠（远处看不出平铺的格子）
	float tFar = smoothstep( 70.0, 240.0, tCam );
	float tBig = 0.82 + 0.36 * ( tN( tP.xz * 0.0055 + 2.3 ) * 0.65 + tN( tP.xz * 0.019 - 4.1 ) * 0.35 );
	float wT = vW.x, wC = vW.y, wR = vW.z;
	float wS = max( 0.0, 1.0 - wT - wC - wR );
	vec2 xz = tP.xz;
	// 0 风纹沙 + 1 细沙细节
	vec4 aS, nS; tSample( tLowQ, 0.0, xz * 0.03333333333333333, tDx.xz * 0.03333333333333333, tDy.xz * 0.03333333333333333, tN( xz * 0.021 ), aS, nS );
	vec3 cS = tGrade( aS.rgb, 0 );
	cS = mix( cS, tGrade( textureLod( tAlb, vec3( 0.5, 0.5, 0.0 ), 12.0 ).rgb, 0 ) * tBig, tFar * 0.8 );
	vec3 nTS = tDecodeN( nS );
	nTS = normalize( mix( nTS, vec3( 0.0, 0.0, 1.0 ), tFar * 0.6 ) );
	float hS = aS.a;
	float fine = TERRAIN_FAR > 0 ? 0.0 : 1.0 - smoothstep( 18.0, 55.0, tCam );
	if ( fine > 0.001 ) {
		vec4 aF, nF; tSample( tLowQ, 1.0, xz * 0.5, tDx.xz * 0.5, tDy.xz * 0.5, tN( xz * 0.13 + 3.3 ), aF, nF );
		vec3 mF = textureLod( tAlb, vec3( 0.5, 0.5, 1.0 ), 12.0 ).rgb;
		cS *= mix( vec3( 1.0 ), aF.rgb / max( mF, vec3( 0.02 ) ), fine * 0.6 );
		nTS = normalize( vec3( nTS.xy + tDecodeN( nF ).xy * fine * 0.8, nTS.z ) );
		nS.b = mix( nS.b, nF.b, fine * 0.5 );
		hS = mix( hS, aF.a, fine * 0.4 );
	}
	// 2 车辙路 3 龟裂地 4 碎石地（权重太小就不采样）
	vec4 aT = vec4( 0.0 ), nT = vec4( 0.5, 0.5, 0.9, 1.0 ), aC = aT, nC = nT, aR = aT, nR = nT;
	if ( wT > 0.004 ) tSample( tLowQ, 2.0, xz * 0.5, tDx.xz * 0.5, tDy.xz * 0.5, tN( xz * 0.17 + 1.7 ), aT, nT );
	if ( wC > 0.004 ) tSample( tLowQ, 3.0, xz * 0.25, tDx.xz * 0.25, tDy.xz * 0.25, tN( xz * 0.09 + 8.1 ), aC, nC );
	if ( wR > 0.004 ) tSample( tLowQ, 4.0, xz * 0.25, tDx.xz * 0.25, tDy.xz * 0.25, tN( xz * 0.12 + 4.4 ), aR, nR );
	// 按高度混合（高处先露出来，边界跟着贴图的起伏走）
	float g = 1.0 - wCliff;
	float b0 = hS * 0.5 + wS * g, b1 = aT.a * 0.5 + wT * g, b2 = aC.a * 0.5 + wC * g, b3 = aR.a * 0.5 + wR * g;
	// 岩壁（三向投影）
	vec3 cK = vec3( 0.0 ), wnK = tNg; float rK = 0.9, oK = 1.0, hK = 0.0;
	if ( wCliff > 0.004 ) {
		vec3 bw = pow( abs( tNg ), vec3( 4.0 ) ); bw /= dot( bw, vec3( 1.0 ) );
		vec3 sg = sign( tNg );
		float s5 = 0.17396421441356202;
		vec2 mX = s5 * vec2( sg.x, 1.0 ), mY = s5 * vec2( sg.y, 1.0 ), mZ = s5 * vec2( - sg.z, 1.0 );
		// 坐标加一层平滑扭曲（几十米尺度），岩壁不再排成一格一格
		vec3 wp = tP + vec3( tN( tP.zy * 0.045 ) - 0.5, tN( tP.xz * 0.045 + 3.7 ) - 0.5, tN( tP.xy * 0.045 - 2.9 ) - 0.5 ) * 9.0;
		vec2 uX = wp.zy * mX, uY = wp.xz * mY, uZ = wp.xy * mZ;
		vec2 xX = tDx.zy * mX, yX = tDy.zy * mX, xY = tDx.xz * mY, yY = tDy.xz * mY, xZ = tDx.xy * mZ, yZ = tDy.xy * mZ;
		vec4 aX = textureGrad( tAlb, vec3( uX, 5.0 ), xX, yX ), aY = textureGrad( tAlb, vec3( uY, 5.0 ), xY, yY ), aZ = textureGrad( tAlb, vec3( uZ, 5.0 ), xZ, yZ );
		vec4 qX = textureGrad( tNra, vec3( uX, 5.0 ), xX, yX ), qY = textureGrad( tNra, vec3( uY, 5.0 ), xY, yY ), qZ = textureGrad( tNra, vec3( uZ, 5.0 ), xZ, yZ );
		vec3 tX = tDecodeN( qX ), tY = tDecodeN( qY ), tZ = tDecodeN( qZ );
		tX.x *= sg.x; tY.x *= sg.y; tZ.x *= - sg.z;
		tX = vec3( tX.xy + tNg.zy, abs( tX.z ) * tNg.x );
		tY = vec3( tY.xy + tNg.xz, abs( tY.z ) * tNg.y );
		tZ = vec3( tZ.xy + tNg.xy, abs( tZ.z ) * tNg.z );
		wnK = normalize( tX.zyx * bw.x + tY.xzy * bw.y + tZ.xyz * bw.z );
		vec4 aK = aX * bw.x + aY * bw.y + aZ * bw.z;
		vec4 qK = qX * bw.x + qY * bw.y + qZ * bw.z;
		// 远处再叠一层 5 倍大的岩壁（大块层理），压掉重复感
		{
			float k5 = 0.2;
			vec4 bX = textureGrad( tAlb, vec3( uX * k5, 5.0 ), xX * k5, yX * k5 ), bY = textureGrad( tAlb, vec3( uY * k5, 5.0 ), xY * k5, yY * k5 ), bZ = textureGrad( tAlb, vec3( uZ * k5, 5.0 ), xZ * k5, yZ * k5 );
			aK = mix( aK, bX * bw.x + bY * bw.y + bZ * bw.z, 0.35 + 0.35 * smoothstep( 40.0, 160.0, tCam ) );
		}
		cK = tGrade( aK.rgb, 5 ) * mix( 1.0, tBig, 0.35 + tFar * 0.35 ); rK = qK.b; oK = qK.a; hK = aK.a;
	}
	float b4 = hK * 0.5 + wCliff;
	float bm = max( max( max( b0, b1 ), max( b2, b3 ) ), b4 ) - 0.2;
	float w0 = max( b0 - bm, 0.0 ), w1 = max( b1 - bm, 0.0 ), w2 = max( b2 - bm, 0.0 ), w3 = max( b3 - bm, 0.0 ), w4 = max( b4 - bm, 0.0 );
	float ws = w0 + w1 + w2 + w3 + w4 + 1e-5;
	w0 /= ws; w1 /= ws; w2 /= ws; w3 /= ws; w4 /= ws;
	vec3 cT = tGrade( aT.rgb, 2 ), cC = tGrade( aC.rgb, 3 ), cR = tGrade( aR.rgb, 4 );
	cT = mix( cT, tGrade( textureLod( tAlb, vec3( 0.5, 0.5, 2.0 ), 12.0 ).rgb, 2 ) * tBig, tFar * 0.7 );
	cC = mix( cC, tGrade( textureLod( tAlb, vec3( 0.5, 0.5, 3.0 ), 12.0 ).rgb, 3 ) * tBig, tFar * 0.7 );
	cR = mix( cR, tGrade( textureLod( tAlb, vec3( 0.5, 0.5, 4.0 ), 12.0 ).rgb, 4 ) * tBig, tFar * 0.7 );
	tCol = cS * w0 + cT * w1 + cC * w2 + cR * w3 + cK * w4;
	tRough = nS.b * w0 + nT.b * w1 + nC.b * w2 + nR.b * w3 + rK * w4;
	tAO = nS.a * w0 + nT.a * w1 + nC.a * w2 + nR.a * w3 + oK * w4;
	// 地面几层的切线法线先混，再接到几何法线上（平面投影：切线 x → 世界 x，切线 y → 世界 z）
	vec3 tn = nTS * w0 + tDecodeN( nT ) * w1 + tDecodeN( nC ) * w2 + tDecodeN( nR ) * w3;
	float wg = w0 + w1 + w2 + w3;
	vec3 wnG = normalize( vec3( tn.x + tNg.x, abs( tn.z ) * tNg.y, tn.y + tNg.z ) );
	// 沙丘起伏：沿风向的沙垄，两组方向、强扭曲叠在一起（不成平行条纹），只改法线；平地近看远看都有起伏和明暗
	{
		float amp = w0 * ( 1.0 - wCliff ) * smoothstep( 0.9, 0.98, tNg.y ) * ( 0.35 + 0.65 * tN( xz * 0.008 + 9.0 ) ) * ( 1.0 - 0.6 * smoothstep( 120.0, 300.0, tCam ) );
		vec2 g2 = vec2( 0.0 );
		for ( int q = 0; q < 2; q ++ ) {
			vec2 wd = q == 0 ? normalize( vec2( 0.8, 0.35 ) ) : normalize( vec2( 0.55, - 0.6 ) );
			float k = q == 0 ? 0.42 : 0.27;
			float ph = dot( xz, wd ) * k + tN( xz * 0.013 + float( q ) * 5.1 ) * 14.0 + tN( xz * 0.05 ) * 2.0;
			float sd = fract( ph / 6.2832 );
			float sl = ( sd < 0.7 ? 0.075 : - 0.18 ) * ( q == 0 ? 1.0 : 0.6 ); // 迎风坡缓、背风坡陡
			g2 += wd * sl;
		}
		wnG = normalize( wnG + vec3( - g2.x, 0.0, - g2.y ) * amp );
	}
	tWN = normalize( wnG * wg + wnK * w4 + tNg * 1e-4 );
	// 焦土：坑心压黑、粗糙
	float sc = vW.w * smoothstep( 0.25, 0.75, tN( xz * 0.13 ) * 0.7 + vW.w * 0.5 );
	tCol *= mix( vec3( 1.0 ), vec3( 0.34, 0.31, 0.29 ), sc );
	tRough = mix( tRough, 1.0, sc * 0.4 );
	// 大尺度明暗（几十米一块），远处不那么平
	tCol *= 0.9 + 0.2 * tMacro;
}

ALBEDO=tCol;ROUGHNESS=craterRoughness(clamp(tRough,0.35,1.0),(VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);NORMAL=normalize(tWN*vec3(-1.0,1.0,1.0));AO=mix(1.0,tAO,0.85);
BACKLIGHT=vec3(vSun);

FOG=craterFog(vTWPos,sourceCamera);
}
