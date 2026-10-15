// Explicit 2x2 box reduction: the native RT backend does not generate mip content.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D source_map : filter_linear, repeat_disable;
uniform float box_width=2.0;
void fragment() {
    vec2 pixel=vec2(1.0)/vec2(textureSize(source_map,0));
    vec3 sum=vec3(0.0);
    // Explicit taps avoid driver-dependent dynamic loops. Every level reads
    // the same source capture; one bilinear tap averages a 2x2 texel block.
    if(box_width<3.0) {
        sum=texture(source_map,UV).rgb;
    } else if(box_width<5.0) {
        sum+=texture(source_map,UV+vec2(-1.0,-1.0)*pixel).rgb*0.25;
        sum+=texture(source_map,UV+vec2(1.0,-1.0)*pixel).rgb*0.25;
        sum+=texture(source_map,UV+vec2(-1.0,1.0)*pixel).rgb*0.25;
        sum+=texture(source_map,UV+vec2(1.0,1.0)*pixel).rgb*0.25;
    } else {
        sum+=texture(source_map,UV+vec2(-3.0,-3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-1.0,-3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(1.0,-3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(3.0,-3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-3.0,-1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-1.0,-1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(1.0,-1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(3.0,-1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-3.0,1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-1.0,1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(1.0,1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(3.0,1.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-3.0,3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(-1.0,3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(1.0,3.0)*pixel).rgb*0.0625;
        sum+=texture(source_map,UV+vec2(3.0,3.0)*pixel).rgb*0.0625;
    }
    ALBEDO=sum;
}
