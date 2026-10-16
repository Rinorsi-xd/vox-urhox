"""Actual frozen H5 two-death install chain versus actual Lua Tick/mission/rules."""
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

reference = json.loads(subprocess.check_output(
    ['node', 'tools/migration/story-install-death-source.mjs'], text=True, encoding='utf-8'))
old_ref = '48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/story/MissionRules.lua'
legacy = subprocess.check_output(['git', 'show', old_ref])
production = (ROOT / 'scripts/story/MissionRules.lua').read_text(encoding='utf-8-sig')


def run(case, code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().RulesCode = code
    lua.globals().Case = lua.table_from(case)
    result = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local noop=function()end
for _,n in ipairs({'story.MissionData','combat.ArenaData','combat.CarUnit','combat.EnemyDriver','core.Math3','drive.SpawnSpecCache',
 'controls.ChaseCamera','controls.ChaseState','render.DriveView','controls.DriveInput','ui.DriveHud','render.CombatEffects','render.CombatView',
 'core.Coord','urhox-libs/UI','ui.DialogHost','render.TargetFeedback'})do package.preload[n]=function()return {}end end
package.preload['render.WeaponView']=function()return {Update=noop}end
package.preload['controls.DriveAim']=function()return {AutoFire=function()return false end}end
KEY_G=1;input={GetKeyDown=function()return false end}
local Rules=assert(load(RulesCode))();package.loaded['story.MissionRules']=Rules
local Mission=require 'story.Mission';local Trial=require 'app.TrialSession'
local function Stub()return setmetatable({active=false},{__index=function()return noop end})end
local r=Rules.New({steps={{id='install',kind='install',pos={0,2,0},r=9},{id='after',kind='reach',pos={1000,2,0},r=1}},spawn={pos={0,2,0},yaw=0}})
r:Begin();r:Go(1);r.time=10;r.install=Case.initial;r.inside=true;r:Drain()
local player={alive=true,pos={0,2,0},Position=function(self)return self.pos end,Spawn=function(self)self.alive=true end}
local body={center=function()return {x=0,y=2,z=0}end}
local vehicle={body=body,speed=0,Yaw=function()return 0 end};player.vehicle=vehicle
local world={time=10,layout={nav={}},units={player},viewEvents={},fx={},debris={events={}},metrics=Stub(),Step=function(self,dt)self.time=self.time+dt end}
local session=setmetatable({pointer={captured=true},controls={held={},Clear=function(self)self.held={}end},accumulator=0,droppedTime=0,fixedSteps=0,vehicle=vehicle,world=world,
 weaponAudio=Stub(),drivingAudio=Stub(),feedbackAudio=Stub(),collisionAudio=Stub(),restoreFlash=Stub(),safeReset=Stub(),
 camera={GetNode=function()return {}end,GetCamera=function()return {}end},view={view=Stub(),SavePose=noop,Update=noop},fxContext={},effects=Stub(),combatView=Stub()},Trial)
local m=setmetatable({rules=r,player=player,entries={{unit=player}},enemyPositions={},session=session,world=world,
 voice={Talking=function()return false end,Say=noop},view=Stub(),radio=Stub(),level={respawn={}}},Mission)
m.BeforeStep=noop;m.SyncPlayer=noop;m.Place=noop;m.CarSize=function()return {w=2,below=1.5,above=1.5}end
local drill={ControlsBody=function()return false end,Latched=function()return false end}
session.weapons={drill=drill};player.weapons={projectiles={}};session.combat=m;session.story=m
local cycles={};local preserved=true
local step=r.Step
r.Step=function(self,dt,snapshot)
 local before=self.install;step(self,dt,snapshot)
 if not snapshot.alive then preserved=preserved and math.abs(self.install-before)<.00000001 end
end
for cycle=1,2 do
 player.alive=false;local wall,frames=0,0
 while not player.alive and frames<2000 do
  session:Tick(1/Case.hz,{throttle=0,steer=0,aim={0,2,1}})
  wall=wall+1/Case.hz;frames=frames+1
 end
 cycles[#cycles+1]={wall=wall,frames=frames,install=r.install,deaths=r.stats.deaths,alive=player.alive}
end
-- Keep gameplay continuation at the same fixed 60Hz input rate on both sides.
r:Step(1/60,{alive=true,pos={0,2,0},speed=0,enemyPositions={},enemies=0,interact=false})
local released={install=r.install,prompt=r.install/2.4}
local held=0
while r.index==1 and held<500 do
 r:Step(1/60,{alive=true,pos={0,2,0},speed=0,enemyPositions={},enemies=0,interact=true});held=held+1
end
return {cycles=cycles,released=released,heldFrames=held,collectors=r.stats.collectors,complete=r.index==2,preserved=preserved}
''')

    def plain(value):
        if hasattr(value, 'items'):
            items = dict(value)
            if items and all(isinstance(k, int) for k in items):
                return [plain(items[k]) for k in range(1, len(items) + 1)]
            return {k: plain(v) for k, v in items.items()}
        return value
    return plain(result)


checks = 0
negatives = []
clock_evidence = []
validated_cases = 0
for case in reference['cases']:
    actual = run(case, production)
    old = run(case, legacy.decode('utf-8-sig'))
    checks += 1
    assert actual['preserved'], (case['hz'], case['initial'], actual)
    if old['released'] != actual['released'] or old['heldFrames'] != actual['heldFrames']:
        negatives.append({'hz': case['hz'], 'initial': case['initial'], 'oldReleased': old['released'],
                          'oldHeldFrames': old['heldFrames'], 'correctHeldFrames': actual['heldFrames']})
    if case['hz'] != 60:
        clock_evidence.append({'hz': case['hz'], 'initial': case['initial'], 'source': case, 'target': actual})
        continue
    validated_cases += 1
    for index, (target, source) in enumerate(zip(actual['cycles'], case['cycles'], strict=True)):
        for key in ['install', 'deaths']:
            checks += 1
            assert abs(target[key] - source[key]) < .00000001, (case, key, target, source)
        checks += 1
        assert target['alive']
        clock_evidence.append({'hz': case['hz'], 'initial': case['initial'], 'cycle': index + 1,
                               'sourceRespawnWall': source['wall'], 'targetRespawnWall': target['wall']})
    for key in ['install', 'prompt']:
        checks += 1
        assert abs(actual['released'][key] - case['released'][key]) < .00000001
    for key in ['heldFrames', 'collectors', 'complete']:
        checks += 1
        assert actual[key] == case[key], (case, key, actual)
checks += 1
assert len(negatives) == 6, 'Actual old production must fail every nonzero-progress case'


def sha(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


paths = ['scripts/story/MissionRules.lua', 'scripts/story/Mission.lua', 'scripts/app/TrialSession.lua']
report = {'result': 'PASS', 'checks': checks, 'sourceCases': len(reference['cases']), 'validated60HzCases': validated_cases,
          'observedOtherRateCasesNotAccepted': len(reference['cases']) - validated_cases, 'source': reference['source'],
          'productionHashes': {path: sha(path) for path in paths},
          'inputs': {path: sha(path) for path in ['tools/migration/story-install-death-source.mjs', 'tools/migration/verify-story-install-death.py']},
          'oldProduction': {'git': old_ref, 'sha256': hashlib.sha256(legacy).hexdigest()},
          'negativeControls': negatives, 'clockObservationNotAccepted': clock_evidence,
          'boundary': 'Actual SHA-verified H5 TestDrive.update/StoryMission.afterStep/update/_respawn versus Lua TrialSession.Tick/Mission.AfterStep/Events/MissionRules. Two deaths, release and rehold accepted ONLY at 60Hz. 30Hz/2Hz are observations, NOT accepted: post-respawn live substeps and capped-simulation clock still differ. Native effects/physics/audio/placement adapters. Wall respawn duration is NOT accepted at any rate. No GPU, browser, natural mission, performance or full G4 acceptance.'}
output = ROOT / 'docs/migration/evidence/story-install-death-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
