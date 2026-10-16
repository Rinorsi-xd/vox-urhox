"""Execute the actual QA lifetime counter with API adapters, without an engine."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

probe = ROOT / 'tools/migration/probe-outgame-web.lua'
source = probe.read_text(encoding='utf-8')
actual = source[source.index('local function BattleObjectState('):source.index('local function DumpTrial(')]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('Time={GetSystemTime=function() return 1000 end}; GetTime=function() return {frameNumber=71} end')
measure = lua.execute(actual + '\nreturn BattleObjectState')
fixture = r'''
local calls={children=0,components=0}
local function Node(n)
 return {GetNumComponents=function() calls.components=calls.components+1;return n end}
end
local scene=Node(2)
scene.GetChildren=function(_,recursive)
 assert(recursive==true);calls.children=calls.children+1;return {Node(3),Node(4)}
end
local player={projectiles={1,2,3,4,5}}
local other={projectiles={1,2,3}}
local session={scene=scene,weapons=player,
 world={units={{alive=true,weapons=player},{alive=true,weapons=other},{alive=false,weapons=other}},
  space={bodies={a={},b={}}},debris={pieces={1,2,3}}},
 effects={particles={1,2},smoke={1},beams={},flashes={1,2,3},
  chips={slots={{active=true},{active=false}},limit=96},
  missiles={booms={1},log={1,2},view={count=1,slots={1,2,3},limit=64}},
  batches={Ribbon={count=3,limit=40,mesh={enabled=true}}}},
 story={explosion={pools={fire={{},{}},core={{}}},rules={fire={{on=true},{on=false}},core={{on=true}},brands={1},fires={},timers={1,2}}}},
 weaponAudio={slots={1,2},loopSources={1,2,3},loopTails={1}},combatView={units={a={},b={}},pieces={a={}}}}
return session,calls
'''
checks = []

def check(label, condition):
    assert condition, label
    checks.append(label)

compiled = lua.eval('function(text) local fn,err=load(text);return fn~=nil,err end')(source)
check('Entire QA probe compiles without execution', compiled[0])
session, calls = lua.execute(fixture)
compact = measure(session, False)
check('F8 table sample performs zero native scene queries', calls.children == calls.components == 0)
check('F8 clearly reports scene as unsampled', compact.scene.sampled is False)
full = measure(session, True)
check('F14 enumerates descendants exactly once', calls.children == 1)
check('F14 reads each node component count once including root', calls.components == 3)
check('F14 exact scene totals include root', full.scene.nodes == 3 and full.scene.components == 9 and full.scene.includesRoot)
check('Player and nonplayer systems counted once despite aliases', full.world.projectiles.player == 5 and full.world.projectiles.other == 3 and full.world.projectiles.total == 8 and full.world.projectiles.systems == 2)
check('Dead and alive world units remain distinct from weapon ownership', full.world.units == 3 and full.world.alive == 2)
check('Physics body and debris counts use existing tables', full.world.physicsBodies == 2 and full.world.debris == 3)
check('Effect list counts preserved', full.effects.lists.particles == 2 and full.effects.lists.smoke == 1 and full.effects.lists.flashes == 3)
check('Chip active and allocated counts separated', full.effects.chips.active == 1 and full.effects.chips.count == 2 and full.effects.chips.limit == 96)
check('Missile active and allocated counts separated', full.effects.missileView.count == 1 and full.effects.missileView.allocated == 3)
check('Batch usage and capacity preserved', full.effects.batches.Ribbon.count == 3 and full.effects.batches.Ribbon.limit == 40)
check('Explosion active flags come from rules', full.storyExplosion.pools.fire.active == 1 and full.storyExplosion.pools.fire.count == 2 and full.storyExplosion.pools.core.active == 1)
check('Audio source pool counts preserve actual allocations', full.weaponAudio.voices == 2 and full.weaponAudio.loopSources == 3 and full.weaponAudio.loopTails == 1)
check('Camera/view ownership counts are table counts', full.combatViews.units == 2 and full.combatViews.pieces == 1)
check('Sample timestamp, frame and cost are explicit', full.at == 1000 and full.frame == 71 and full.elapsedMs == 0)
check('Observer does not change gameplay tables', len(session.weapons.projectiles) == 5 and len(session.world.units) == 3 and session.effects.chips.slots[1].active is True)
empty = measure(lua.table(), False)
check('Unconstructed optional pools remain safe', empty.world.units == 0 and empty.world.projectiles.total == 0)
failed = measure(lua.table(), True)
check('Unavailable engine scene API is reported rather than invented', failed.scene.supported is False and failed.scene.sampled is True)
check('Only explicit F8 enables table sample', 'if input:GetKeyPress(KEY_F8) then pendingBattleObjects=true end' in source)
check('Only independent F14 enables scene traversal', 'if input:GetKeyPress(KEY_F14) then pendingBattleObjects=true;pendingSceneObjects=true end' in source and source.count('pendingSceneObjects=true') == 1)
check('Sample request consumed once', 'pendingBattleObjects=false;local sceneRequested=pendingSceneObjects;pendingSceneObjects=false' in source)
check('Counters execute only when explicitly pending', 'if pendingBattleObjects then' in source and source.count('BattleObjectState(s,sceneRequested)') == 1)
check('Default automatic and explicit F13 history behavior preserved; route mode suppresses duplicates', 'frames%30==0 and not G0_StoryRouteState or input:GetKeyPress(KEY_F8) or pendingPresentationHistory or pendingSceneObjects' in source and "historyMode=full and 'full' or 'last'" in source)
mutations = [
 ('F8 starts native traversal', 'if sceneRequested then', 'if true then', lambda value, recorded: recorded.children == 0),
 ('Player system double counts', 'if not system or seen[system] then return end', 'if not system then return end', lambda value, recorded: value.world.projectiles.total == 8),
 ('Root omitted', 'return #children+1,total', 'return #children,total', lambda value, recorded: value.scene.nodes == 3),
 ('Enemy projectiles omitted', 'Weapons(unit.weapons);if unit.alive', 'if unit.alive', lambda value, recorded: value.world.projectiles.other == 3),
]
for label, before, after, predicate in mutations:
    assert before in actual
    mutant = lua.execute(actual.replace(before, after) + '\nreturn BattleObjectState')
    adapted, recorded = lua.execute(fixture)
    result = mutant(adapted, label != 'F8 starts native traversal')
    check('Negative control rejected: ' + label, not predicate(result, recorded))

report = {'result': 'PASS', 'checks': checks, 'probeSha256': hashlib.sha256(probe.read_bytes()).hexdigest(),
          'inputs': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in [probe, Path(__file__)]},
          'apiReferenceHashes': {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['.emmylua/Node.d.lua', '.emmylua/InputEvents.d.lua']},
          'apiEvidence': ['.emmylua/Node.d.lua:633 GetChildren(recursive)', '.emmylua/Node.d.lua:607 GetNumComponents()', '.emmylua/InputEvents.d.lua:217 KEY_F14'],
          'boundary': 'CPU execution of actual observer with documented Node API adapters. No native/browser/GPU run, native heap allocation measurement or performance acceptance. F8 counts existing small Lua pools only; F14 explicitly traverses descendants once and reports cost. Automatic and F13 dumps never request this traversal.'}
output = ROOT / 'docs/migration/evidence/battle-object-probe-offline.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(checks), 'probeSha256': report['probeSha256'], 'output': str(output)}))
