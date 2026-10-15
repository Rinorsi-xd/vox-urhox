shader_type spatial;
render_mode unshaded, fog_disabled;
varying vec4 cubeColor;
void vertex() { cubeColor = INSTANCE_COLOR; }
void fragment() { ALBEDO = cubeColor.rgb; }
