shader_type spatial;
render_mode shading_model_unlit, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float clock = 0.0;
uniform float beam_length = 0.0;
uniform float power = 0.0;
void vertex() {
    VERTEX.y *= beam_length;
}
void fragment() {
    float rim = abs(dot(NORMAL, normalize(CAMERA_POSITION_WORLD - VERTEX)));
    float core = pow(rim, 3.0);
    float ripple = 0.75 + 0.25 * sin(UV.y * 80.0 - clock * 90.0);
    vec3 color = mix(vec3(1.0, 0.08, 0.04), vec3(1.0, 0.85, 0.75), core) * (0.6 + core * 2.4) * ripple;
    ALBEDO = color * power * rim;
    ALPHA = 1.0;
}
