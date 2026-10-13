// Separable Gaussian for the frozen inventory's CSS blur(4px).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform vec2 direction = vec2(0.0);
void fragment() {
    vec3 c = texture(source_map, UV).rgb * 0.099908358105;
    c += (texture(source_map, UV + direction * 1.476579651064).rgb + texture(source_map, UV - direction * 1.476579651064).rgb) * 0.185003317647;
    c += (texture(source_map, UV + direction * 3.445529535040).rgb + texture(source_map, UV - direction * 3.445529535040).rgb) * 0.136012267620;
    c += (texture(source_map, UV + direction * 5.414898845797).rgb + texture(source_map, UV - direction * 5.414898845797).rgb) * 0.078176874429;
    c += (texture(source_map, UV + direction * 7.384912144484).rgb + texture(source_map, UV - direction * 7.384912144484).rgb) * 0.035127823675;
    c += (texture(source_map, UV + direction * 9.355774893514).rgb + texture(source_map, UV - direction * 9.355774893514).rgb) * 0.012338326786;
    c += (texture(source_map, UV + direction * 11.327668300821).rgb + texture(source_map, UV - direction * 11.327668300821).rgb) * 0.003387210791;
    ALBEDO = c;
}
