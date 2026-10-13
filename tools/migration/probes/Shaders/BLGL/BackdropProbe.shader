shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float phase = 0.0;
void fragment() {
    if (UV.y < 0.25) ALBEDO = UV.x < 0.5 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    else if (UV.y > 0.75) ALBEDO = UV.x < 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 1.0, 0.0);
    else if (UV.y > 0.55 && UV.y < 0.65) ALBEDO = vec3(phase);
    else ALBEDO = UV.x < 0.5 ? vec3(0.0) : vec3(1.0);
}
