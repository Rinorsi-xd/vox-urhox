shader_type spatial;
render_mode shading_model_pbr, blend_mix, depth_draw_never, cull_back;
uniform sampler2D image_map : filter_linear_mipmap, repeat_disable;
uniform vec3 primary_color = vec3(1.0);
uniform vec3 secondary_color = vec3(1.0);
uniform float shape_mask = 0.0;
uniform float opacity = 1.0;
vec3 linear_color(vec3 c) {
    return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
    vec4 t = texture(image_map, UV);
    vec3 c = mix(t.rgb, primary_color * t.r + secondary_color * t.g, shape_mask);
    ALBEDO = linear_color(c);
    ALPHA = t.a * opacity;
    ALPHA_SCISSOR_THRESHOLD = 0.03;
    ROUGHNESS = 0.5;
    METALLIC = 0.02;
    CLEARCOAT = 0.25;
    CLEARCOAT_ROUGHNESS = 0.4;
}
