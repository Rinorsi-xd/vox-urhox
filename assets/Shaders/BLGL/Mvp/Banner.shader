shader_type spatial;
render_mode shading_model_pbr,cull_disabled;
uniform sampler2D albedo_map : source_color,filter_linear_mipmap,repeat_disable;
uniform sampler2D shape_map : filter_linear,repeat_disable;
uniform float unroll=0.001;
uniform float age=0.0;
// render.PortraitCheck canvas, as in CommsPortrait.shader: its left column is a
// NanoVG target with red painted on top. Sampling blue there means NanoVG targets
// read back upside down on this device, so the NanoVG-drawn albedo flips too.
uniform sampler2D orient_map : filter_nearest, repeat_disable;
uniform float orient_enabled=0.0;
void vertex(){
    float v=UV.y,s=(v-unroll)*4.2;
    if(s>0.0){float a=s/.07,r=.07*(1.0-.12*min(a/6.2832,3.0));VERTEX.y=-unroll*4.2-r*sin(a);VERTEX.z=r-r*cos(a);}
    else VERTEX.z+=sin(VERTEX.x*2.1+age*1.7+v*4.0)*.05*v+sin(age*1.1+VERTEX.x)*.03*v;
}
void fragment(){
    vec2 uv=UV;
    if(orient_enabled>0.5){vec4 o=texture(orient_map,vec2(0.1875,0.1875));uv.y=mix(uv.y,1.0-uv.y,step(0.5,o.a)*step(o.r,o.b));}
    vec4 t=texture(albedo_map,uv);ALBEDO=t.rgb;ALPHA=texture(shape_map,UV).a;ALPHA_SCISSOR_THRESHOLD=.5;ROUGHNESS=.62;METALLIC=.08;EMISSION=vec3(.0103298,.00060705,.0012141);}
