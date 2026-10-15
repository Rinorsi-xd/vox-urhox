shader_type spatial;
render_mode shading_model_unlit,blend_mix,depth_draw_never,cull_disabled;
uniform float age=0.0;
void vertex(){
    vec3 center=VERTEX+NORMAL*(1.0-exp(-age*3.0))/3.0;
    float size=(.5+age*1.8)*length(MODEL_MATRIX[0].xyz);
    vec3 world=(MODEL_MATRIX*vec4(center,1.0)).xyz;
    world+=(INV_VIEW_MATRIX*vec4((UV-.5)*size,0.0,0.0)).xyz;
    VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1.0)).xyz;
}
void fragment(){
    float r=length(UV-.5)*2.0;
    ALBEDO=mix(vec3(1.0),vec3(1.0,.7605,.4342),clamp(r/.4,0.0,1.0));
    float a=r<.4?mix(.8157,.502,r/.4):mix(.502,0.0,clamp((r-.4)/.6,0.0,1.0));
    ALPHA=a*.75*max(0.0,1.0-age/1.2);
}
