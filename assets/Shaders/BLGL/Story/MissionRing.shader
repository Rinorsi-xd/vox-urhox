shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 uColor = vec3(1.0, 0.416, 0.075);
uniform float uTime = 0.0;
uniform float uProgress = 0.0;
void fragment() {
    vec2 p = vec2(UV.x, 1.0 - UV.y) * 2.0 - 1.0;
    float r = length(p);
    float ang = atan(p.x, p.y) / 6.2831853 + 0.5;
    float base = smoothstep(0.93, 0.95, r) * (1.0 - smoothstep(0.985, 1.0, r));
    float tick = step(0.5, fract(ang * 48.0 - uTime * 0.3)) * smoothstep(0.80, 0.82, r) * (1.0 - smoothstep(0.86, 0.88, r));
    float fill = step(ang, uProgress) * smoothstep(0.86, 0.88, r) * (1.0 - smoothstep(0.92, 0.94, r));
    float a = base * 0.9 + tick * 0.35 + fill + (1.0 - smoothstep(0.0, 0.95, r)) * 0.08;
    ALBEDO = uColor * a; ALPHA = a;
}
