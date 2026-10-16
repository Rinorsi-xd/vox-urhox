shader_type spatial;
render_mode shading_model_unlit, blend_add, cull_back, depth_draw_never;

varying float flash_alpha;
varying vec3 flash_tint;
uniform float joined_alpha = -1.0;
uniform vec3 joined_color = vec3(1.0);
uniform vec3 flash_color = vec3(0.04970657, 0.79129794, 1.0);

void vertex() {
    flash_alpha = joined_alpha >= 0.0 ? joined_alpha : INSTANCE_COLOR.a;
    flash_tint = joined_alpha >= 0.0 ? joined_color : INSTANCE_COLOR.rgb;
}

void fragment() {
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - VERTEX);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), view_dir)), 2.0);
    ALBEDO = flash_color * flash_tint * (0.55 + 1.6 * rim) * flash_alpha;
    ALPHA = 1.0;
}
