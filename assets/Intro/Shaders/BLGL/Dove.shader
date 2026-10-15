// Original HoloDove shader. Tile centres are supplied through vertex COLOR.xy.
shader_type spatial;
render_mode shading_model_unlit, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D dove_map : source_color, filter_linear, repeat_disable;
uniform float clock = 0.0;
uniform float break_amount = 0.0;
uniform float glitch = 0.0;
uniform float opacity = 0.0;
uniform float hit = 0.0;
void vertex() {
    vec3 centre = vec3(-(COLOR.x - 0.5) * 24.0, (COLOR.y - 0.5) * 24.0, 0.0);
    vec3 rnd = vec3(fract(sin(COLOR.x * 71.7 + COLOR.y * 39.1) * 43758.5453), COLOR.z, COLOR.w);
    rnd.xy = rnd.xy * 2.0 - 1.0;
    float b = break_amount;
    vec3 off = VERTEX - centre;
    float angle = b * rnd.x * 9.0;
    off.xy = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * off.xy * (1.0 - b * 0.4);
    vec3 direction = normalize(vec3(centre.xy + rnd.xy * 3.0, (rnd.z - 0.3) * 10.0));
    VERTEX = centre + off + direction * b * (14.0 + rnd.z * 26.0) + vec3(0.0, -b * b * 18.0, 0.0);
    VERTEX.x += glitch * sin(centre.y * 3.1 + clock * 60.0) * 0.9 * step(0.6, fract(centre.y * 0.37 + clock * 7.0));
    VERTEX.y += sin(clock * 1.3) * 0.4 * (1.0 - b);
}
void fragment() {
    vec4 c = texture(dove_map, vec2(UV.x, 1.0 - UV.y));
    float scan = 0.82 + 0.18 * sin(UV.y * 420.0 - clock * 9.0);
    float flicker = 0.9 + 0.1 * sin(clock * 37.0) * sin(clock * 13.0);
    vec3 color = mix(c.rgb, vec3(0.75, 0.95, 1.0), 0.35) * scan * flicker;
    color = mix(color, vec3(1.0, 0.25, 0.15), hit);
    float alpha = c.a * opacity * (1.0 - break_amount) * (1.0 - glitch * 0.4 * step(0.5, fract(UV.y * 20.0 + clock * 11.0)));
    ALBEDO = color * alpha * 1.25;
    ALPHA = 1.0;
}
