"""Translate the frozen StoryHolo shader bodies, without replacing their art."""
from pathlib import Path
import json, re

root = Path(__file__).resolve().parents[2]
baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text('utf8'))
source = (Path(baseline['snapshot']) / 'three/src/ui/storyHolo.js').read_text('utf8')
out = root / 'assets/Shaders/BLGL/Story'
out.mkdir(parents=True, exist_ok=True)
mapping = {'Terrain': 'HOLO_FS', 'Floor': 'FLOOR_FS', 'Shell': 'MODEL_FS', 'Depth': 'MODEL_DEPTH_FS', 'Dash': 'DASH_FS', 'Beam': 'BEAM_FS'}
for name, key in mapping.items():
    body = re.search(r'const ' + key + r' = `(.*?)`;', source, re.S)[1]
    body = re.sub(r'varying\s+\w+\s+\w+;', '', body)
    body = body.replace('uniform float uTime;', 'uniform float uTime = 0.0;')
    body = body.replace('uniform float uR;', 'uniform float uR = 4.6;')
    body = body.replace('uniform float uGain;', 'uniform float uGain = 1.0;')
    body = body.replace('uniform float uLen;', 'uniform float uLen = 1.0;')
    body = body.replace('uniform vec3 uColor;', 'uniform vec3 uColor = vec3(0.06125,0.57758,1.0);')
    inputs = 'vec3 vP=VERTEX*vec3(-1.0,1.0,1.0);vec3 vW=vP;float vH=vP.y;float vS=1.0-NORMAL.y;vec3 vN=NORMAL;vec3 vV=VIEW;vec2 vUv=vec2(UV.x,1.0-UV.y);'
    body = body.replace('void main() {', 'void fragment() {' + inputs)
    if name == 'Depth':
        body = body.replace('gl_FragColor = vec4( 0.0 );', 'ALBEDO=vec3(0.0);ALPHA=0.0;')
        mode = 'unshaded,blend_mix,depth_draw_always,cull_disabled,fog_disabled'
    else:
        # Three's additive ShaderMaterial writes source RGB times source alpha.
        body = body.replace('gl_FragColor = vec4( c * a, 1.0 );', 'ALBEDO=pow(max(c*a,vec3(0.0)),vec3(2.2));ALPHA=1.0;')
        body = body.replace('gl_FragColor = vec4( col * a, a );', 'ALBEDO=pow(max(col*a*a,vec3(0.0)),vec3(2.2));ALPHA=1.0;')
        body = body.replace('gl_FragColor = vec4( uColor * a, a );', 'ALBEDO=pow(max(uColor*a*a,vec3(0.0)),vec3(2.2));ALPHA=1.0;')
        mode = 'unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled'
    assert 'gl_FragColor' not in body, name
    (out / (name + '.shader')).write_text('shader_type spatial;\nrender_mode ' + mode + ';\n' + body, encoding='utf8')
(out / 'Solid.shader').write_text('''shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;
uniform vec3 uColor=vec3(1.0);
uniform float opacity=1.0;
void fragment(){ALBEDO=pow(uColor*opacity,vec3(2.2));ALPHA=1.0;}
''', encoding='utf8')
print('Translated 6 frozen StoryHolo shaders and its solid/edge material')
