// Copy a camera-rendered snapshot into a target that NanoVG shows upright.
// Reading the source may reverse rows (sampled), showing the copy through NanoVG
// may flip it (shown); both are vertical mirrors, so flip when exactly one applies.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "Orientation.shaderinc"
uniform sampler2D source_map : filter_linear, repeat_disable;
void fragment() {
    float flip=abs(orient_rt_sampled_flip()-orient_rt_shown_flip());
    ALBEDO=texture(source_map,orient_apply(UV,flip)).rgb;
}
