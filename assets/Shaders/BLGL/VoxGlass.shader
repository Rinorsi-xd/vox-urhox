// 玻璃方块（对应 H5 的 MeshPhysicalMaterial：transmission 1、roughness 0.24、ior 1.46、清漆 0.25）
// 全透射玻璃没有漫反射：看到的是身后场景经轻微折射、按粗糙度模糊、再被玻璃颜色（实例色）染色后的透射光，
// 叠加表面的镜面反射与清漆高光。身后场景从屏幕颜色纹理里取（多点采样模拟模糊）。
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_pbr, blend_mix, cull_back;

uniform sampler2D screen_color : hint_screen_texture;
uniform float roughness_value = 0.24;
uniform float use_vertex_color = 0.0;
uniform float blur_px = 11.0;
uniform float refract_offset = 0.012;

varying vec4 inst_color;

void vertex() {
    inst_color = mix(INSTANCE_COLOR, COLOR, use_vertex_color);
}

void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    vec3 n = normalize(NORMAL);
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - VERTEX);
    float ndv = clamp(abs(dot(n, view_dir)), 0.0, 1.0);
    // ior 1.46 → F0 ≈ 0.035
    float fres = 0.035 + 0.965 * pow(1.0 - ndv, 5.0);

    // 折射：沿视空间法线把采样点推开一点
    vec3 nv = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
    vec2 suv = SCREEN_UV - nv.xy * refract_offset;
    vec2 px = vec2(1.0) / VIEWPORT_SIZE * blur_px;
    vec3 bg = texture(screen_color, suv).rgb * 0.2;
    bg += texture(screen_color, suv + vec2(px.x, 0.0)).rgb * 0.1;
    bg += texture(screen_color, suv - vec2(px.x, 0.0)).rgb * 0.1;
    bg += texture(screen_color, suv + vec2(0.0, px.y)).rgb * 0.1;
    bg += texture(screen_color, suv - vec2(0.0, px.y)).rgb * 0.1;
    bg += texture(screen_color, suv + px * 0.7).rgb * 0.1;
    bg += texture(screen_color, suv - px * 0.7).rgb * 0.1;
    bg += texture(screen_color, suv + vec2(px.x, -px.y) * 0.7).rgb * 0.1;
    bg += texture(screen_color, suv - vec2(px.x, -px.y) * 0.7).rgb * 0.1;

    ALBEDO = vec3(0.0);
    METALLIC = 0.0;
    ROUGHNESS = roughness_value;
    SPECULAR = 0.44;
    CLEARCOAT = 0.25;
    CLEARCOAT_ROUGHNESS = 0.35;
    EMISSION = bg * inst_color.rgb * (1.0 - fres);
    ALPHA = 1.0;
}
