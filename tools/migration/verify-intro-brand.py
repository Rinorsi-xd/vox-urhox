"""Frozen CSS animation values versus production Lua; no browser/visual acceptance."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

registry = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
source_root = ROOT / '.tmp/outgame-source-2026-10-15T12-35-57-243Z'
css_path = source_root / 'shared/css/intro.css'
css = css_path.read_text(encoding='utf-8')
logo_path = source_root / 'three/src/intro/introLogo.js'
logo = logo_path.read_text(encoding='utf-8')
checks = 0

def check(value, message):
    global checks
    assert value, message
    checks += 1

def rule(selector):
    found = re.search(re.escape(selector) + r'\s*\{([^}]+)\}', css)
    check(found is not None, selector)
    return found.group(1)

def animation(selector, name):
    body = rule(selector)
    value = re.search(r'animation:\s*([^;]+)', body).group(1)
    match = re.search(re.escape(name) + r'\s+(\.?\d+(?:\.\d+)?)s\s*(?:(\.?\d+(?:\.\d+)?)s\s*)?(cubic-bezier\([^)]+\)|ease-in|ease)?', value)
    check(match is not None, name)
    curve = match.group(3) or 'ease'
    control = tuple(map(float, curve[curve.index('(')+1:-1].split(','))) if curve.startswith('cubic') else {'ease': (.25, .1, .25, 1), 'ease-in': (.42, 0, 1, 1)}[curve]
    return float(match.group(1)), float(match.group(2) or 0), control

def ease(value, control):
    if value <= 0: return 0
    if value >= 1: return 1
    x1, y1, x2, y2 = control
    def cubic(t, a, b): return 3 * (1-t)**2*t*a + 3*(1-t)*t*t*b+t**3
    # Independent high precision inversion, not production's fixed iteration count.
    lo, hi = 0.0, 1.0
    for _ in range(60):
        mid = (lo+hi)/2
        if cubic(mid, x1, x2) < value: lo = mid
        else: hi = mid
    return cubic((lo+hi)/2, y1, y2)

curves = {name: animation(selector, name) for name, selector in [
    ('ip2Line', '#intro .ip2-line'), ('ip2LineOut', '#intro .ip2-line'),
    ('ip2Mask', '#intro .ip2-mark'), ('ipFade', '#intro .ip2-word'),
    ('ip2Track', '#intro .ip2-en')]}
meta_curve = animation('#intro .ip2-meta', 'ipFade')
letter_css = rule('#intro .ip2-name i')
check('ip2Up .5s calc(.6s + var(--i) * .06s)' in letter_css, 'letter duration/delay')
letter_control = tuple(map(float, re.search(r'cubic-bezier\(([^)]+)\)', letter_css).group(1).split(',')))
check('translateY(105%)' in rule('@keyframes ip2Up').split('from')[1], 'letter entry distance')
check('circle(75% at 50% 50%)' in css, 'mask final radius')
check('letter-spacing: .42em' in rule('#intro .ip2-en'), 'tracking final')
check('letter-spacing: 1.2em' in rule('@keyframes ip2Track'), 'tracking start')
check('height: 1px' in rule('#intro .ip2-line'), 'line thickness')
check('background: #0c0d10' in rule('#intro .ip2'), 'background color')
check('* 8)' in rule('#intro .ip2-grid'), '8vh grid')
check('* 10)/1' in rule('#intro .ip2-name'), '10vh title')
check('EST. 2187' in logo and "[ ...'星际前途' ]" in logo, 'brand content')

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path; package.loaded['ui.SourceDraw']={}; package.loaded['urhox-libs/UI/Core/ImageCache']={}")
brand = lua.eval("require('ui.IntroBrand')")[0]
def sample(name, age):
    duration, delay, control = curves[name]
    return ease((age-delay)/duration, control)

ages = sorted(set([i/600 for i in range(1801)] + [.35,.5,.6,.66,.72,.78,.85,.9,.95,1,1.1,1.28,1.5,1.75,2.9]))
for age in ages:
    actual = brand.Plan(age)
    expected = {'line': sample('ip2Line',age), 'lineAlpha': 1-sample('ip2LineOut',age),
        'mask': .75*sample('ip2Mask',age), 'wordAlpha': sample('ipFade',age),
        'englishAlpha': sample('ip2Track',age), 'englishSpacing': 1.2-.78*sample('ip2Track',age),
        'metaAlpha': ease((age-meta_curve[1])/meta_curve[0],meta_curve[2])}
    for key, value in expected.items(): check(abs(actual[key]-value)<2e-6, f'{key}@{age}: {actual[key]} != {value}')
    for i in range(4):
        expected_letter=1-ease((age-.6-i*.06)/.5,letter_control)
        check(abs(actual.letters[i+1]-expected_letter)<2e-6, f'letter{i}@{age}')

draw_result = lua.execute((ROOT / 'tools/migration/check-intro-brand.lua').read_text(encoding='utf-8'))
checks += draw_result['checks']
film = lua.eval("require('ui.IntroFilm')")[0]
intro_source = (source_root/'three/src/intro/intro.js').read_text(encoding='utf-8')
sortie_source = (source_root/'three/src/intro/introSortie.js').read_text(encoding='utf-8')
bar_events = [('idyll',3,True),('prosper',9,False),('sortie-brief',16,True),('sortie-play',20,False),('familiar',40,False),('galaxy',46,True),('m-build',66,True)]
check("this.L.bars.classList.remove( 'on' )" in intro_source.split('async actVirtues()')[1].split('async actNo()')[0], 'source comic removes cinema bars')
check("I.L.bars.classList.add( 'on' )" in sortie_source, 'source playable insert enables bars')
check('height .7s cubic-bezier(.16, 1, .3, 1)' in css, 'source cinema transition')
check('transition: opacity .4s' in rule('#intro .in-film'), 'source film fade')
film_log=[]
for event, at, on in bar_events:
    film_log.append({'shot':event,'t':at})
    for age in [0,.001,.1,.25,.4,.69,.7,1,2]:
        owner = lua.table_from({'time':at+age,'shot':event,'age':age,'log':lua.table_from([lua.table_from(entry) for entry in film_log])})
        plan=film.Plan(owner)
        prev = 0 if len(film_log)==1 else int(bar_events[len(film_log)-2][2])
        expected_bar=prev+(int(on)-prev)*ease(age/.7,(.16,1,.3,1))
        check(abs(plan.bars-expected_bar)<2e-6,f'cinema bars {event}@{age}')
        check(abs(plan.film-ease((at+age-3)/.4,(.25,.1,.25,1)))<2e-6,f'film {event}@{age}')
        check(plan.logo == (at+age-3 < .26),f'logo closing clock {event}@{age}')
film_draw = lua.execute((ROOT/'tools/migration/check-intro-film.lua').read_text(encoding='utf-8'))
checks += film_draw['checks']
current_promo=(ROOT/'scripts/ui/IntroPromo.lua').read_text(encoding='utf-8')
previous_promo=subprocess.check_output(['git','show','HEAD:scripts/ui/IntroPromo.lua'],encoding='utf-8')
def caption_block(text): return text.split(" if I.caption and I.caption~='' then\n",1)[1].split('\n end\n',1)[0]
check(caption_block(current_promo)==caption_block(previous_promo),'subtitle bytes remain unchanged from tracked opening')
for path in ['scripts/ui/IntroBrand.lua','scripts/ui/IntroFilm.lua','scripts/ui/IntroPromo.lua']:
    loaded=lua.eval('load')( (ROOT/path).read_text(encoding='utf-8'),path )
    check(not isinstance(loaded,tuple),f'{path} Lua 5.4 syntax')
result = {'status': 'PASS', 'checks': checks, 'animationSamples':len(ages), 'drawCalls':draw_result['drawCalls'],
    'source': {'branch':'2026-10-15','commit':'b276064942ae09c0227ec28d4cfda1d5ff006455',
        'cssSha256': hashlib.sha256(css_path.read_bytes()).hexdigest(), 'logoSha256':hashlib.sha256(logo_path.read_bytes()).hexdigest()},
    'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/ui/IntroBrand.lua','scripts/ui/IntroFilm.lua','scripts/ui/IntroPromo.lua']},
    'notVerified':['actual Web rendering','natural full opening','phone performance','CSS blur exactness']}
out = ROOT / 'docs/migration/evidence/intro-brand-offline.json'
out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
