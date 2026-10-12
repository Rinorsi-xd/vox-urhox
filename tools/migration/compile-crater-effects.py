from pathlib import Path
import re
root=Path(__file__).resolve().parents[2];out=root/'assets/Shaders/BLGL/Crater';source=Path('D:/Rino_Project/Vox/three/src')
air=(source/'terrain/airFx.js').read_text('utf8');puff=re.search(r'const PUFF_FRAG = /\* glsl \*/`([\s\S]*?)`;',air)[1]
puff=re.sub(r'varying vec2 vUv; varying vec4 vLook; varying vec3 vC; varying float vFade;','',puff)
puff=puff.replace('uniform vec3 uSunCol;','uniform vec3 uSunCol=vec3(.8963,.5776,.2961);')
puff=puff.replace('void main() {','void fragment() {\nvec2 vUv=UV;vec4 vLook=vec4(COLOR.a,COLOR.r,COLOR.g,0.0);float vFade=1.0;')
puff=puff.replace('gl_FragColor = vec4( col, a );','ALBEDO=col;ALPHA=a;')
(out/'Puff.shader').write_text('shader_type spatial;\nrender_mode unshaded,blend_mix,cull_disabled,depth_draw_never;\n'+puff,encoding='utf8')
sh=(source/'battle/shieldFx.js').read_text('utf8');sh=re.search(r'const FRAG = /\* glsl \*/`([\s\S]*?)`;',sh)[1].replace('${HITS}','8')
# Keep the source's eight-slot hit buffer and complete state formula. The Lua
# presentation uploads the fixed float buffer only when a hit/reset changes it.
sh=sh.replace('uniform float uHP;','uniform float uHP=1.0;').replace('uniform float uDown;','uniform float uDown=0.0;').replace('uniform float uRaise;','uniform float uRaise=1.0;')
sh=sh.replace('varying vec3 vW;','').replace('varying vec3 vN;','varying vec3 sourceScaledNormal;')
sh=sh.replace('void main() {','void fragment() {\nvec3 vW=VERTEX*vec3(-1.0,1.0,1.0);vec3 vN=sourceScaledNormal*vec3(-1.0,1.0,1.0);vec3 cameraPosition=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);')
sh=sh.replace('gl_FrontFacing','FRONT_FACING').replace('gl_FragColor = vec4( c, 1.0 );','ALBEDO=c;ALPHA=1.0;')
(out/'Shield.shader').write_text('shader_type spatial;\nrender_mode unshaded,blend_add,cull_disabled,depth_draw_never,fog_disabled;\n'+sh+'\nvoid vertex(){vL=VERTEX;sourceScaledNormal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}\n',encoding='utf8')

# Preserve the original ground-streak noise and edge/fade formula.
dust=(source/'terrain/dust.js').read_text('utf8')
streak=re.findall(r'fragmentShader: /\* glsl \*/`([\s\S]*?)`',dust)[1]
streak=streak.replace('varying vec2 vUv; varying vec3 vW;','')
streak=streak.replace('void main() {','void fragment(){vec2 vUv=UV;vec3 vW=VERTEX*vec3(-1.0,1.0,1.0);vec3 cameraPosition=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);')
streak=streak.replace('gl_FragColor = vec4( uColor * 1.05, a * edge * 0.2 * smoothstep( 2.0, 8.0, dist ) );','ALBEDO=uColor*1.05;ALPHA=a*edge*0.2*smoothstep(2.0,8.0,dist);')
(out/'Streak.shader').write_text('shader_type spatial;\nrender_mode unshaded,blend_mix,cull_disabled,depth_draw_never,fog_disabled;\n'+streak,encoding='utf8')
(out/'Mote.shader').write_text("""shader_type spatial;
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
""",encoding='utf8')
