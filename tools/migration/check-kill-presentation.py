"""Sample parsed frozen CSS against actual Lua kill drawing and recorded DOM evidence."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
import tinycss2

source = json.loads(subprocess.check_output(['node', 'tools/migration/part-hit-flash-source.mjs'], text=True, encoding='utf-8'))
rules = tinycss2.parse_stylesheet(source['css'], skip_comments=True, skip_whitespace=True)


def declarations(tokens):
    return {item.name: tinycss2.serialize(item.value).strip() for item in tinycss2.parse_declaration_list(tokens, skip_comments=True, skip_whitespace=True) if item.type == 'declaration'}


styles = {}
frames = {}
for rule in rules:
    if rule.type == 'qualified-rule':
        styles[tinycss2.serialize(rule.prelude).strip()] = declarations(rule.content)
    elif rule.type == 'at-rule' and rule.at_keyword == 'keyframes':
        name = tinycss2.serialize(rule.prelude).strip()
        frames[name] = [(float(tinycss2.serialize(item.prelude).strip().removesuffix('%')) / 100, declarations(item.content))
                        for item in tinycss2.parse_rule_list(rule.content, skip_comments=True, skip_whitespace=True)]


def timing(value):
    for token in tinycss2.parse_component_value_list(value):
        if token.type == 'function' and token.name == 'cubic-bezier':
            return tuple(float(part.value) for part in token.arguments if part.type == 'number')
        if token.type == 'ident' and token.value == 'ease-out':
            return (0, 0, .58, 1)
    raise AssertionError('Source animation easing not found')


def ease(progress, curve):
    if progress <= 0:
        return 0
    if progress >= 1:
        return 1
    x1, y1, x2, y2 = curve
    low, high = 0.0, 1.0

    def cubic(t, a, b):
        return 3 * (1-t)**2 * t * a + 3 * (1-t) * t*t * b + t**3

    for _ in range(60):
        mid = (low + high) / 2
        if cubic(mid, x1, x2) < progress:
            low = mid
        else:
            high = mid
    return cubic((low + high) / 2, y1, y2)


def value(text, prop):
    if prop == 'translate':
        return float(text.split()[1].removesuffix('px'))
    return float(text)


def sample(name, prop, progress, default, curve):
    stops = {at: value(row[prop], prop) for at, row in frames[name] if prop in row}
    stops.setdefault(0, default)
    stops.setdefault(1, default)
    ordered = sorted(stops.items())
    if progress >= 1:
        return stops[1]
    for (a, start), (b, end) in zip(ordered, ordered[1:]):
        if a <= progress <= b:
            result = start + (end-start) * ease((progress-a)/(b-a), curve)
            return min(1, max(0, result)) if prop == 'opacity' else result
    raise AssertionError('Source keyframe outside range')


def color(text):
    assert text.startswith('#')
    digits = text[1:]
    if len(digits) in [3, 4]:
        digits = ''.join(ch*2 for ch in digits)
    result = [int(digits[i:i+2], 16) for i in range(0, len(digits), 2)]
    return result if len(result) == 4 else result + [255]


def shadows(text, pixel):
    groups = [[]]
    for token in tinycss2.parse_component_value_list(text):
        if token.type == 'literal' and token.value == ',':
            groups.append([])
        elif token.type != 'whitespace':
            groups[-1].append(token)
    result = []
    for group in groups:
        lengths = [float(t.value)*pixel for t in group if t.type in ['number', 'dimension']]
        shade = next(color('#'+t.value) for t in group if t.type == 'hash')
        result.append({'x': lengths[0], 'y': lengths[1], 'blur': lengths[2], 'color': shade})
    return result


kill_curve = timing(styles['#combatFx .kill.on']['animation'])
slam_curve = timing(styles['#combatFx .kill.on .pts']['animation'])
old_draw = subprocess.check_output(['git', 'show', '48ef15f2:scripts/ui/CombatFeedbackDraw.lua']).decode('utf-8')
current_draw = (ROOT / 'scripts/ui/CombatFeedbackDraw.lua').read_text(encoding='utf-8')
current_helper = (ROOT / 'scripts/ui/CombatFeedbackPresentation.lua').read_text(encoding='utf-8')


def runtime(draw_source=current_draw, helper_source=current_helper):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().draw_source = draw_source
    lua.globals().helper_source = helper_source
    render = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
package.preload['ui.CombatFeedbackPresentation']=assert(load(helper_source))
local texts,stack={},{}
local pose={alpha=1,sx=1,sy=1,x=0,y=0}
local function Copy(v) local o={};for k,p in pairs(v)do o[k]=p end;return o end
function nvgSave()stack[#stack+1]=Copy(pose)end
function nvgRestore()pose=table.remove(stack)end
function nvgGlobalAlpha(_,a)pose.alpha=a end
function nvgTranslate(_,x,y)pose.x=pose.x+x;pose.y=pose.y+y end
function nvgScale(_,x,y)pose.sx=pose.sx*x;pose.sy=pose.sy*y end
local D={}
function D.Text(_,text,x,y,size,fill,font,align,spacing,baseline,lineHeight,shadow)
 texts[#texts+1]={text=text,x=x,y=y,size=size,color=fill,font=font,spacing=spacing,shadows=shadow,pose=Copy(pose)}
end
function D.Width(_,text,size,_,spacing)return utf8.len(text)*(size*.5+(spacing or 0))end
function D.FontMetrics(_,size)return size*.8,size*.2 end
package.loaded['ui.SourceDraw']=D
package.loaded['ui.ReticleDraw']={red={255,74,58,255},white={242,246,248,255}}
NVG_ALIGN_CENTER=2;NVG_ALIGN_LEFT=1
local Draw=assert(load(draw_source))()
return function(age,n,k,pixel,bump)
 texts={};stack={};pose={alpha=1,sx=1,sy=1,x=0,y=0}
 Draw.Render(0,{low=0,repairAge=9,flash=0,hits={},cubes={},score={age=age,n=n,bump=bump or 0,size=(58+math.min(4,n-1)*6)*k,shown=300,name='Source target'}},
 {cx=960*k,cy=540*k,width=1920*k,height=1080*k,k=k,pixel=pixel})
 assert(#stack==0,'VG state stack restored')
 return texts
end
''')
    return lua, render


checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


def near(actual, expected, label):
    check(abs(actual-expected) < 2e-5, label+': '+str(actual)+' vs '+str(expected))


def verify(render, ages, streaks, bump=0):
    for k, pixel in [(1, 1), (.6, 1), (1.25, 1.5)]:
        for n in streaks:
            pts_style = dict(styles['#combatFx .kill .pts'])
            if n > 1:
                pts_style.update(styles['#combatFx .kill.streak .pts'])
            for age in ages:
                actual = render(age, n, k, pixel, bump)
                if age >= 2:
                    check(len(actual) == 0, 'source expired kill hidden')
                    continue
                check(len(actual) == 3, 'points and subtitle retained')
                points, label, name = actual[1], actual[2], actual[3]
                alpha = sample('cfKill', 'opacity', age/2, 0, kill_curve)
                child_alpha = sample('cfSlam', 'opacity', age/.32, 1, slam_curve)
                scale = sample('cfSlam', 'scale', age/.32, 1, slam_curve)
                lift = sample('cfKill', 'translate', age/2, 0, kill_curve) * pixel
                near(points['pose']['alpha'], alpha*child_alpha, 'actual points source opacity')
                near(label['pose']['alpha'], alpha, 'actual subtitle source opacity')
                near(points['pose']['sx'], scale, 'actual source slam scale')
                near(points['pose']['y'], 610*k+points['size']/2+lift, 'actual source lift')
                check([points['color'][i] for i in range(1, 5)] == color(pts_style['color']), 'actual streak score color')
                check(points['font'] == 'vox-display' and label['font'] == name['font'] == 'vox-title', 'font mappings unchanged')
                near(points['size'], (58+min(4, n-1)*6)*k, 'score font size unchanged')
                near(label['size'], (24 if n > 1 else 16)*k, 'label font size unchanged')
                near(name['size'], 16*k, 'name font size unchanged')
                for row, expected in [(points, shadows(pts_style['text-shadow'], pixel)),
                                      (label, shadows(styles['#combatFx .kill .who']['text-shadow'], pixel)),
                                      (name, shadows(styles['#combatFx .kill .who']['text-shadow'], pixel))]:
                    check(row['shadows'] is not None and len(row['shadows']) == len(expected), 'actual source text shadow layers')
                    for index, shade in enumerate(expected, 1):
                        for field in ['x', 'y', 'blur']:
                            near(row['shadows'][index][field], shade[field], 'actual CSS px shadow '+field)
                        check([row['shadows'][index]['color'][i] for i in range(1, 5)] == shade['color'], 'actual source shadow RGBA')


lua, render = runtime()
ages = [0, .001, .016, .032, .06, .08, .12, .16, .1919, .192, .224, .256, .3199, .32, .5, 1.64, 1.68, 1.82, 1.95, 1.9999, 2]
verify(render, ages, range(1, 6))
verify(render, ages, range(1, 6), .07)
browser_path = 'docs/migration/evidence/kill-css-bump.json'
browser = json.loads((ROOT / browser_path).read_text(encoding='utf-8'))
check(browser['result'] == 'PASS' and not browser['errors'], 'actual DOM CSS cascade passed')
check(browser['source']['sha256'] == source['source']['shared/ui/combatFeedback.js'], 'actual DOM evidence uses frozen source')
check(browser['source']['commit'] == source['baseline']['commit'] and browser['source']['branch'] == source['baseline']['branch'],
      'actual DOM evidence uses frozen baseline')
check(browser['canvasCount'] == 0 and '--disable-webgl' in browser['args'], 'DOM-only evidence boundary')
check(browser['positiveControl']['transitions'] > 0 and float(browser['positiveControl']['added']['scale']) == 1.12,
      'actual original bump rule works without animation')
check(len(browser['samples']) == 18, 'actual browser sample matrix complete')
for row in browser['samples']:
    for phase in ['before', 'added', 'removed']:
        check(abs(float(row[phase]['scale'])-sample('cfSlam', 'scale', row['age']/.32, 1, slam_curve)) < 2e-5,
              'actual browser scale agrees with parsed CSS golden')
    check(row['before']['scale'] == row['added']['scale'] == row['removed']['scale'], 'actual filled animation masks bump')
    check(not any(item['type'] == 'CSSTransition' for item in row['added']['animations']), 'masked bump starts no transition')
negative = []
for label, draw_text, helper_text in [
    ('actual 48ef old early slam', old_draw, current_helper),
    ('actual 48ef old chain color/shadow', old_draw, current_helper),
    ('linear easing mutation', current_draw, current_helper.replace('return Cubic((lo+hi)/2,y1,y2)', 'return p')),
    ('fixed score color mutation', current_draw, current_helper.replace('streak>1 and {255,226,122,255} or ', '')),
    ('missing score shadow mutation', current_draw.replace('nil,nil,nil,style.points', 'nil,nil,nil,nil'), current_helper),
    ('extra Lua bump multiplier mutation', current_draw.replace('local scale=motion.scale', 'local scale=motion.scale;if s.bump>0 then scale=scale*1.12 end'), current_helper),
]:
    test_lua, test_render = runtime(draw_text, helper_text)
    try:
        verify(test_render, [.5] if 'chain' in label or 'color' in label or 'shadow' in label else [.032], [2], .07 if 'bump' in label else 0)
    except AssertionError as error:
        negative.append({'name': label, 'detected': True, 'reason': str(error)})
    else:
        raise AssertionError('Negative control accepted: '+label)

report = {'result': 'PASS', 'checks': checks, 'drawCases': len(ages)*5*3*2, 'negativeControls': negative,
          'source': source['source'], 'baseline': source['baseline'],
          'production': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in
                         ['scripts/ui/CombatFeedbackDraw.lua', 'scripts/ui/CombatFeedbackPresentation.lua']},
          'before': {'commit': '48ef15f2', 'drawSha256': hashlib.sha256(old_draw.encode('utf-8')).hexdigest()},
          'evidenceReportHashes': {browser_path: hashlib.sha256((ROOT / browser_path).read_bytes()).hexdigest()},
          'testInputs': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in
                         ['tools/migration/check-kill-presentation.py', 'tools/migration/check-kill-css-bump.cjs',
                          'tools/migration/part-hit-flash-source.mjs']},
          'browserCascade': {'browser': browser['browser'], 'samples': len(browser['samples']), 'conclusion': browser['conclusion']},
          'boundary': 'Parsed actual frozen CSS using tinycss2, independent 60-iteration CSS cubic interpolation, actual Lua draw recorder at 21 ages / 5 streaks / 3 layout scales / 2 bump states. Actual recorded Chrome DOM evidence verifies scale cascade with GPU/WebGL disabled; no game loaded. Native NanoVG glyph rasterization/shadow footprint, visible game composition, natural kill and mobile frame time remain OPEN.'}
output = ROOT / 'docs/migration/evidence/kill-presentation-offline.json'
output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, indent=2))
