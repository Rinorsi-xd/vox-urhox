shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never,fog_disabled;
uniform float uTime=0.0;
varying float moteFade;
varying float moteSun;
void vertex(){
    // Source dust.js drift/wrap/fade; UrhoX mirrors source X and looks along +Z.
    float moteSeed=NORMAL.x;
    vec3 moteInitial=VERTEX*vec3(-1.0,1.0,1.0)+vec3(45.0,6.0,45.0);
    vec3 moteCamera=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);
    vec3 moteBase=moteCamera-vec3(45.0,6.0,45.0);
    vec3 moteDrift=vec3(.9161573349,0.0,.400818834)*uTime*(1.2+moteSeed*1.6);
    moteDrift.y=sin(uTime*.6+moteSeed*40.0)*.6+uTime*.05*(moteSeed-.5);
    vec3 moteWorld=mod(moteInitial+moteDrift-moteBase,vec3(90.0,24.0,90.0))+moteBase;
    vec3 moteNative=moteWorld*vec3(-1.0,1.0,1.0);
    vec3 moteDelta=moteNative-CAMERA_POSITION_WORLD;
    float moteDepth=dot(moteDelta,INV_VIEW_MATRIX[2].xyz);
    moteFade=smoothstep(2.5,7.0,moteDepth)*(1.0-smoothstep(25.0,44.0,moteDepth));
    moteSun=pow(max(dot(normalize(moteWorld-moteCamera),vec3(-.5209,.5009,-.6912)),0.0),4.0);
    // Source diameter = (0.3+seed*0.7)*viewportHeight/10/depth pixels.
    float moteRadius=(.3+moteSeed*.7)*.1/abs(PROJECTION_MATRIX[1][1]);
    vec2 moteCorner=UV*2.0-1.0;
    VERTEX=moteNative-MODEL_MATRIX[3].xyz+(INV_VIEW_MATRIX[0].xyz*moteCorner.x+INV_VIEW_MATRIX[1].xyz*moteCorner.y)*moteRadius;
}
void fragment(){
    ALBEDO=vec3(.8963,.5776,.2961)*(.9+moteSun*2.0);
    ALPHA=(1.0-smoothstep(0.0,.5,length(UV-.5)))*moteFade*(.1+moteSun*.3);
}
