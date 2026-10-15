shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
uniform sampler2D puff_map : source_color, filter_linear, repeat_disable;
uniform float uClock = 0.0;
uniform float uKind = 0.0;
uniform vec3 uRight = vec3(1.0, 0.0, 0.0);
uniform vec3 uUp = vec3(0.0, 1.0, 0.0);
varying vec4 particle;
varying float age;
vec3 ramp(float u) {
    float f = clamp(u, 0.0, 0.999) * 5.0;
    vec3 a = vec3(1.0, 0.871367119, 0.434153636);
    vec3 b = vec3(1.0, 0.434153636, 0.051269458);
    if (f >= 4.0) { a = vec3(0.102241733, 0.017641954, 0.005181517); b = vec3(0.015996293, 0.009134059, 0.006048833); }
    else if (f >= 3.0) { a = vec3(0.479320183, 0.039546235, 0.003676507); b = vec3(0.102241733, 0.017641954, 0.005181517); }
    else if (f >= 2.0) { a = vec3(0.887923118, 0.144128471, 0.010329823); b = vec3(0.479320183, 0.039546235, 0.003676507); }
    else if (f >= 1.0) { a = vec3(1.0, 0.434153636, 0.051269458); b = vec3(0.887923118, 0.144128471, 0.010329823); }
    return mix(a, b, fract(f));
}
void vertex() {
    particle = INSTANCE_COLOR;
    float life = max(0.0, uClock - INSTANCE_CUSTOM.x);
    age = life / max(0.0001, INSTANCE_CUSTOM.y);
    float size = mix(INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, 1.0 - pow(max(0.0, 1.0 - age), 2.2));
    float angle = particle.z + particle.w * life;
    vec2 q = (UV - vec2(0.5)) * size;
    vec2 r = vec2(cos(angle)*q.x - sin(angle)*q.y, sin(angle)*q.x + cos(angle)*q.y);
    VERTEX = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + uRight*r.x + uUp*r.y;
}
void fragment() {
    vec4 texel = texture(puff_map, UV);
    float alpha = 0.0;
    vec3 color = vec3(0.0);
    if (uKind < 0.5) {
        color = ramp(particle.x + age*1.1);
        alpha = min(1.0, age/0.06) * (age < 0.55 ? 1.0 : 1.0-(age-0.55)/0.45) * particle.y;
    } else {
        color = vec3(particle.x + age*0.12);
        alpha = min(1.0, age/0.15)*(1.0-age)*particle.y;
    }
    ALBEDO = texel.rgb*color;
    ALPHA = texel.a*max(0.0, alpha);
}
