"""Run actual Host.Update/VehicleView.UpdateIdle with controlled engine adapters."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

CURRENT = ROOT / 'scripts/app/OpeningHost.lua'
FROZEN = ROOT / '.tmp/outgame-cached-1792111525141/scripts/app/OpeningHost.lua'
CODE = r'''
package.path='scripts/?.lua;'..package.path
local noop=function()end
for _,name in ipairs({'construction.Blueprint','core.Coord','Config','parts.Defs',
 'parts.PartAssets','render.PartRig','render.JoinedSurface'}) do package.loaded[name]={} end
package.loaded['app.SceneLoader']={New=function()return{Update=noop}end}
local operations=0
local function work() operations=operations+1 end
package.loaded['render.WeaponPresentation']={Update=work}
package.loaded['render.WingRig']={Update=work}
local View=assert(loadfile('scripts/render/VehicleView.lua'))()
local Host=assert(loadfile(HOST_PATH))()
local rows={}
for _,sessionOn in ipairs({false,true}) do
 for _,scene in ipairs({'garage','crater'}) do
  local host=Host.New({});local actor={root={enabled=false},joined={Update=work},
   livery={Update=work},rotorJoined={{Update=work}},visuals={}}
  for n=1,200 do actor.visuals[n]={weaponMotion=true,rig={wing=true}} end
  actor.UpdateIdle=View.UpdateIdle
  host.state.hallActor=actor;host.state.activeScene=scene
  if sessionOn then host.state.session={Tick=noop} end
  host.state.garage={Update=noop}
  local I={ready=true,playing=false,shot='fixture',time=0}
  local row={}
  for _,visible in ipairs({false,true,false,true}) do
   actor.root.enabled=visible;local before=operations
   for frame=1,60 do I.time=I.time+1/60;host.Update(1/60,I) end
   row[#row+1]=operations-before
  end
  rows[#rows+1]={sessionOn,scene,row}
 end
end
return rows
'''

def run(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().HOST_PATH = path.as_posix()
    rows = lua.execute(CODE)
    return [{'session': row[1], 'scene': row[2],
             'operations': list(row[3].values())} for row in rows.values()]

paths = (CURRENT, FROZEN, ROOT / 'scripts/render/VehicleView.lua')
hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
before, after = run(FROZEN), run(CURRENT)
checks = 0
for old, new in zip(before, after):
    expected = [0, 24180, 0, 24180] if new['scene'] == 'garage' else [0, 0, 0, 0]
    assert new['operations'] == expected, new
    assert old['operations'] == ([24180] * 4 if old['scene'] == 'garage' else [0] * 4), old
    checks += 8
assert any(old['operations'] != new['operations'] for old, new in zip(before, after))
assert hashes == {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
report = {'result': 'PASS', 'checks': checks, 'productionHashes': hashes,
          'frozen': before, 'current': after,
          'scope': 'Actual Lua Host.Update and VehicleView.UpdateIdle; 200 synthetic animated parts, '
                   '60 frames per visibility phase, session present/absent and garage/crater. '
                   'Proves hidden work skipped and visible work/reentry retained; no GPU, '
                   'wall-time speedup, full animation visual or 589 ms handoff acceptance.'}
out = ROOT / 'docs/migration/evidence/opening-hidden-idle-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': checks, 'evidence': str(out)}))
