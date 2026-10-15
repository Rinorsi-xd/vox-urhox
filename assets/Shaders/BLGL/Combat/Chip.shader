shader_type spatial;
render_mode shading_model_pbr, cull_back;
varying vec4 paint;
void vertex() { paint=INSTANCE_COLOR; }
void fragment() { ALBEDO=paint.rgb; ROUGHNESS=0.6; METALLIC=0.1; }
