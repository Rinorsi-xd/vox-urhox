// Copy a camera-rendered snapshot into a target that NanoVG shows upright.
// Two device quirks are detected on the GPU, never read back on the CPU:
// - sentinel_map (render.PortraitCheck's sentinel, red top half in render space)
//   tells whether sampling a render target in a shader returns rows reversed;
// - orient_map (the PortraitCheck canvas) tells whether a render target drawn by
//   NanoVG is shown upside down, exactly as CommsPortrait.shader reads it.
// Both are vertical mirrors, so the copy flips when exactly one of them applies.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform sampler2D sentinel_map : filter_nearest, repeat_disable;
uniform sampler2D orient_map : filter_nearest, repeat_disable;
void fragment() {
    vec4 s=texture(sentinel_map,vec2(0.5,0.25));
    float sampled=step(0.5,s.a)*step(s.r,s.b);
    vec4 l=texture(orient_map,vec2(0.1875,0.1875)),r=texture(orient_map,vec2(0.8125,0.1875));
    float shown=step(0.5,l.a)*step(0.5,r.a)*step(0.5,abs(l.r-r.r));
    float flip=abs(sampled-shown);
    vec2 uv=vec2(UV.x,mix(UV.y,1.0-UV.y,flip));
    ALBEDO=texture(source_map,uv).rgb;
}
