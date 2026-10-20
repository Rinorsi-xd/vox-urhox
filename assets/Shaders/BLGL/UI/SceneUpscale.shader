// render.MobileSceneScale: copy the reduced-resolution battle scene onto the screen.
// sentinel_map is render.PortraitCheck's sentinel (red top half in render space);
// when sampling a render target returns rows reversed on this device, flip back.
// Without a sentinel the fallback texture has zero alpha, so nothing flips.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform sampler2D sentinel_map : filter_nearest, repeat_disable;
void fragment() {
    vec4 s=texture(sentinel_map,vec2(0.5,0.25));
    float flip=step(0.5,s.a)*step(s.r,s.b);
    ALBEDO=texture(source_map,vec2(UV.x,mix(UV.y,1.0-UV.y,flip))).rgb;
}
