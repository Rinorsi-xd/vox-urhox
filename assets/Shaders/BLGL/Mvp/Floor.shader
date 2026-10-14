shader_type spatial;
render_mode shading_model_pbr,cull_disabled;
void fragment(){
    vec2 d=abs(fract(UV+.5)-.5);vec2 aa=max(fwidth(UV),vec2(.001));
    float grid=1.0-min(smoothstep(.005,.005+aa.x,d.x),smoothstep(.005,.005+aa.y,d.y));
    ALBEDO=mix(vec3(.0544803,.0703601,.0908417),vec3(.0975873,.1247718,.1589608),grid*.65);ROUGHNESS=.95;
}
