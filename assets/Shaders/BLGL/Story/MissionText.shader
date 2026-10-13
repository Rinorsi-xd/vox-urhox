shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D text_map : source_color, filter_linear, repeat_disable;
uniform float opacity = 1.0;
void fragment() { vec4 color = texture(text_map, vec2(1.0 - UV.x, UV.y)); ALBEDO = color.rgb; ALPHA = color.a * opacity; }
