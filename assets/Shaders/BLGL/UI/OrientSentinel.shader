// render.PortraitCheck sentinel: a camera-rendered target with the same marker
// convention as CommsPortrait (red where the portrait's top-left marker sits,
// blue where its bottom-left one does), split into two halves so any texel row
// answers. It feeds the orientation map when no portrait is on screen, and
// OrientedCopy samples it to learn how render targets read back in shaders.
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
void fragment() {
    float top=step(0.5,1.0-UV.y);
    ALBEDO=mix(vec3(0.0,0.0,1.0),vec3(1.0,0.0,0.0),top);
    ALPHA=1.0;
}
