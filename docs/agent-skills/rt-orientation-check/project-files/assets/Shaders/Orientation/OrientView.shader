// render.OrientationSelfTest viewer: shows view_map on a v=0-top quad.
// mode 0 raw, 1 camera RT sampled (sentinel fix), 2 NanoVG RT sampled (map fix).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "Orientation.shaderinc"
uniform sampler2D view_map : filter_linear, repeat_disable;
uniform float mode = 0.0;
void fragment() {
    float flip=step(0.5,mode)*step(mode,1.5)*orient_rt_sampled_flip()
              +step(1.5,mode)*step(mode,2.5)*orient_nvg_sampled_flip()
              +step(2.5,mode)*orient_rt_shown_flip();
    ALBEDO=texture(view_map,orient_apply(UV,flip)).rgb;
}
