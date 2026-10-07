shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform vec3 value = vec3(4.0, 2.0, 0.5);
uniform float stage = 0.0;
void fragment() {
    vec3 c = texture(source_map, UV).rgb;
    if (stage < 0.5) c = value;
    else if (stage < 1.5) c *= 0.98;
    else {
        vec3 error = abs(c - value);
        c = max(max(error.r, error.g), error.b) < 0.03 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    }
    ALBEDO = c;
}
