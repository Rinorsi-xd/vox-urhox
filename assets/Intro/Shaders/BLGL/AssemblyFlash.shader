// Frozen vehicleView.flashMaterial: source rim, colour and additive fade.
shader_type spatial;
render_mode shading_model_unlit, blend_add, depth_draw_never;
void vertex() { COLOR=INSTANCE_COLOR; }
void fragment() {
    vec3 view_dir=normalize(CAMERA_POSITION_WORLD-VERTEX);
    float rim=pow(1.0-abs(dot(normalize(NORMAL),view_dir)),2.0);
    ALBEDO=COLOR.rgb*(0.55+1.6*rim)*COLOR.a;
    ALPHA=1.0;
}
