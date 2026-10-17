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
    // Mask texels satisfy r+g=1 wherever alpha>0; filtering against transparent (rgb=0)
    // texels shrinks r+g at the edge, so renormalise to keep the edge colour, not darken it.
    vec2 w = t.rg / max(t.r + t.g, 1e-3);
    vec3 c = mix(t.rgb, primary_color * w.x + secondary_color * w.y, shape_mask);
    ALBEDO = linear_color(c);
    ALPHA = t.a * opacity;
    ALPHA_SCISSOR_THRESHOLD = 0.03;
    ROUGHNESS = 0.5;
    METALLIC = 0.02;
    CLEARCOAT = 0.25;
    CLEARCOAT_ROUGHNESS = 0.4;
}
