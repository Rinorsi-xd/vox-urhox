// render.OrientationMap sentinel: a camera-rendered target, red top half and blue
// bottom half in render space (UV v=0 is the quad's top vertex). It feeds the
// orientation map when no live marker source is on screen, and consumers sample
// it directly to learn whether render targets read back reversed in shaders.
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
void fragment() {
    float top=step(0.5,1.0-UV.y);
    ALBEDO=mix(vec3(0.0,0.0,1.0),vec3(1.0,0.0,0.0),top);
    ALPHA=1.0;
}
