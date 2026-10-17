"""Execute frozen FoxBoss._missiles and production StoryBoss.Projectiles."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference = json.loads(subprocess.check_output(['node', 'tools/migration/story-boss-missile-feedback-source.mjs'], encoding='utf-8'))
path = ROOT / 'scripts/combat/StoryBoss.lua'
original_bytes = path.read_bytes()
current = original_bytes.decode('utf-8-sig')
data = json.loads((ROOT / 'assets/Story/Mission/Level5.json').read_text(encoding='utf-8-sig'))


def run(test, code):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict): return lua.table_from({k: convert(v) for k, v in value.items()})
        if isinstance(value, list): return lua.table_from([convert(v) for v in value])
        return value

    def plain(value):
        if not hasattr(value, 'items'): return value
        rows = dict(value)
        if all(isinstance(k, int) for k in rows): return [plain(rows[k]) for k in range(1, len(rows) + 1)]
        return {k: plain(v) for k, v in rows.items()}

    lua.globals().TEST = convert(test)
    lua.globals().DATA = convert(data)
    lua.globals().CODE = code
    return plain(lua.execute(r'''
package.path='scripts/?.lua;'..package.path
for _,name in ipairs({'construction.Blueprint','combat.ArenaData','parts.Dependencies','render.BossView','Config','drive.RotorMotion',
 'combat.DriverActions','combat.WeaponDefs','combat.BossExposedDelay','render.BossSceneCapture','render.WindowViewports',
 'combat.CarUnit','combat.EnemyDriver','combat.EnemyDriverNav','core.Coord','audio.StoryRadio'})do package.preload[name]=function()return {}end end
package.preload['core.ResourceData']=function()return {Read=function()return DATA end}end
local Boss=assert(load(CODE))()
local calls,rays,frames={},{},{}
local step={}
local function unit(name)
 local u={name=name,alive=name~='player' or not TEST.dead,pos={TEST.distance or 4,0,0},vehicle={body=name}}
 function u:Position()return self.pos end
 function u:Explode(at,radius,damage)calls[#calls+1]={'explode',name,radius,damage}end
 function u:Flush()calls[#calls+1]={'flush',name}end
 return u
end
local player,ally=unit('player'),unit('ally')
local voice={Talking=function()return step.talking==true end,Say=function(_,lines,urgent,append)calls[#calls+1]={'say',lines,urgent,append}end}
local self=setmetatable({time=10,step=DATA.level.steps[2],rules={hp=1},pending={},missiles={},allies=TEST.ally and {{unit=ally}} or {},
 unit={vehicle={body='boss'}},session={trauma=TEST.trauma or 0},mission={player=player,voice=voice,rules={stats={}}},
 Fx=function(_,at,size,big)calls[#calls+1]={'fx',size,big==true}end},{__index=Boss})
if TEST.synthetic then
 local lines={};for key,value in pairs(self.step.lines)do lines[key]=value end
 lines.outside={'nono','controlled missing-cue gate','nono_neutral'};self.step={lines=lines}
end
local world={}
function world:CastRay(origin,dir,length,exclude)
 local up=dir[2]==1;rays[#rays+1]={up and 'roof' or 'los',exclude or false}
 local kind=up and step.roof or step.los
 if not kind or kind=='none' then return nil end
 local ref=kind=='boss' and self.boss or kind=='player' and player or kind=='ally' and ally or {}
 return {dist=kind=='far' and 100 or 0,owner=kind~='unknown' and {ref=ref} or nil}
end
world.boss=self.unit;self.world=world
for _,s in ipairs(TEST.steps)do
 step=s;self.storyUntil=s.busy and 11 or 0
 self.missiles[#self.missiles+1]={from={0,0,0},mid={0,0,0},to={0,0,0},prev={0,0,0},t=0,duration=1,r=7.5,damage=340,hist={}}
 self:Projectiles(1)
 frames[#frames+1]={trauma=self.session.trauma,hits=self.mission.rules.stats.missileHits or 0,said=self.said and self.said.outside==true or false,remaining=#self.missiles}
end
return {calls=calls,rays=rays,frames=frames}
'''))


def normalize(value):
    if isinstance(value, list): return [normalize(v) for v in value]
    if isinstance(value, dict): return {k: normalize(v) for k, v in value.items()}
    return False if value is None else value


checks = 0
for case in reference['cases']:
    got = run(case['test'], current)
    want = normalize(case['expected'])
    assert got == want, (case['test']['name'], got, want)
    checks += len(got['calls']) + len(got['rays']) + 4 * len(got['frames'])
feedback = """                            self.session.trauma=math.max(self.session.trauma or 0,.35)
                            local roof=self.world:CastRay(V.Add(u:Position(),{0,4,0}),{0,1,0},90,u.vehicle and u.vehicle.body)
                            if not roof or roof.owner and roof.owner.ref==self.unit then self:Once('outside') end
"""
assert feedback in current
before_path = ROOT / '.tmp/outgame-cached-1792209050608/scripts/combat/StoryBoss.lua'
before_bytes = before_path.read_bytes()
assert hashlib.sha256(before_bytes).hexdigest() == '1c83a942b7cb45981fec0a61de889efc83eaceb481a7efa513060ef2dac507a9'
after_block = """                        if u==self.mission.player then
                            self.mission.rules.stats.missileHits=(self.mission.rules.stats.missileHits or 0)+1
""" + feedback + """                        end"""
before_block = "if u==self.mission.player then self.mission.rules.stats.missileHits=(self.mission.rules.stats.missileHits or 0)+1 end"
assert current.replace(after_block, '                        ' + before_block).encode('utf-8') == before_bytes, 'Unexpected additional production edits'
mutants = {
    'previous-production-missing-feedback': current.replace(feedback, ''),
    'overwrite-stronger-impact': current.replace('math.max(self.session.trauma or 0,.35)', '.35'),
    'ignore-shelter': current.replace("if not roof or roof.owner and roof.owner.ref==self.unit then self:Once('outside') end", "self:Once('outside')"),
    'repeat-bark': current.replace("self:Once('outside')", "self:Say('outside')"),
    'exclude-boss-instead-of-player': current.replace('90,u.vehicle and u.vehicle.body)', '90,self.unit.vehicle.body)'),
}
negative = {}
for name, code in mutants.items():
    assert code != current, name
    failures = [case['test']['name'] for case in reference['cases'] if run(case['test'], code) != normalize(case['expected'])]
    assert failures, name
    negative[name] = failures
assert path.read_bytes() == original_bytes, 'Production changed during test'
paths = ['scripts/combat/StoryBoss.lua', 'tools/migration/story-boss-missile-feedback-source.mjs', 'tools/migration/verify-story-boss-missile-feedback.py', 'assets/Story/Mission/Level5.json']
report = {'result': 'PASS', 'cases': len(reference['cases']), 'checks': checks, 'source': reference['source'], 'negativeControls': negative,
          'actualAuthoredCases': sum(not c['test'].get('synthetic', False) for c in reference['cases']),
          'syntheticCueGateCases': sum(c['test'].get('synthetic', False) for c in reference['cases']),
          'previousProduction': {'path': str(before_path.relative_to(ROOT)).replace('\\', '/'), 'sha256': hashlib.sha256(before_bytes).hexdigest()},
          'productionHashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'boundary': 'Actual frozen FoxBoss._missiles -> _explodeMissile -> _team/_sheltered/once/say/talk versus actual Lua StoryBoss.Projectiles -> Team/Once/Say. Raycast, vehicle damage and voice sink are controlled doubles. No Native/Web visual, audible playback, natural S5 or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/story-boss-missile-feedback-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
