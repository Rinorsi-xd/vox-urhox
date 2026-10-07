// Original holoPartMaterial: local-axis rotation, scanlines, flicker, rim.
// Instance RGB carries the source paint colour; alpha is not opacity.
shader_type spatial;
#include "lib/PlanarClip.shaderinc"
render_mode shading_model_unlit, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled;
#include "lib/VoxDecorMotion.shaderinc"
varying float local_y;
varying vec3 paint_color;
void vertex() {
    local_y = VERTEX.y;
    paint_color = INSTANCE_COLOR.rgb;
    float angle = vox_decor_time() * 0.8;
    VERTEX = vox_decor_spin(VERTEX, angle);
    NORMAL = vox_decor_spin(NORMAL, angle);
}
void fragment() {
    if (planar_clip_reject(VERTEX, VIEW_MATRIX, IN_SHADOW_PASS)) discard;
    float t = vox_decor_time();
    float scan = 0.75 + 0.25 * sin(local_y * 160.0 - t * 6.0);
    float flick = 0.92 + 0.08 * sin(t * 31.0) * sin(t * 7.0);
    float facing = clamp(abs(dot(normalize(NORMAL), normalize(CAMERA_POSITION_WORLD - VERTEX))), 0.0, 1.0);
    float rim = 0.6 + 0.8 * pow(1.0 - facing, 2.0);
    ALBEDO = paint_color * 1.6 * scan * flick * rim;
    ALPHA = 0.0;
}
