"""Execute frozen JS radio/music/sample methods and actual Lua audio modules."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/source-match-mvp-audio.cjs'],text=True))
assert [row['speaking'] for row in reference['radio']['speaking']]==[1,0,0,0,1,0,0]
paths=['scripts/audio/MatchVoice.lua','scripts/audio/MvpMusic.lua']
prior=ROOT/'.tmp/outgame-cached-1792117688715'
old_hashes=['bf8dceff0fe73e939a161a030dc8c3f479ecbed66dd0eb93f4f283b6688bd661','2e76473c8289c7eed9b1b93768e6694c103a5a6cdeee9a59e56cf85c01a30b10']
configs={p:json.loads((ROOT/'assets'/p).read_text(encoding='utf8')) for p in ['Combat/Radio.json','Mvp/Beats.json','Mvp/Cues.json','UI/Music/Catalog.json']}
# This ownership oracle supplies a two-second line; real PCM/DSP timing is
# independently covered by check-match-radio-dsp.py.
configs['Combat/MatchRadioDSP.json']=json.loads((ROOT/'assets/Combat/MatchRadioDSP.json').read_text())
for line in configs['Combat/MatchRadioDSP.json']['lines'].values():
    line.update(duration=2,total=2.52,speaking=2.5)
    for lane,stem in line['stems'].items():
        stem['at']={'voice':.26,'hiss':.06,'lead':.02,'tail':2.26}[lane]
checks=0
def check(ok,label):
    global checks
    checks+=1
    assert ok,label
def table(lua,value):
    if isinstance(value,dict):return lua.table_from({k:table(lua,v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([table(lua,v) for v in value])
    return value
def run(match,mvp,phase='all'):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().CONFIG=table(lua,configs)
    lua.globals().REF=table(lua,reference)
    lua.globals().MATCH=match
    lua.globals().MVP=mvp
    lua.globals().PHASE=phase
    lua.globals().check=check
    return dict(lua.execute('''
package.path='scripts/?.lua;'..package.path
Time={GetSystemTime=function()return 0 end};input={focus=true,minimized=false}
local paused={};audio={PauseSoundType=function(_,kind)paused[kind]=true end,ResumeSoundType=function(_,kind)paused[kind]=false end}
package.loaded['core.ResourceData']={Read=function(p)return assert(CONFIG[p],p)end}
package.loaded['app.ResourceGate']={New=function()return {Start=function(_,_,fn)fn(true)end,Cancel=function()end}end}
package.loaded['combat.MvpMotion']={Beat=function()return {}end}
local function node()
 return {CreateChild=function()return node()end,CreateComponent=function()
  return {SetSoundType=function(self,kind)self.soundType=kind end,Play=function(self,sound,_,gain)self.sound=sound;self.gain=gain;self.playing=true end,
   StopImmediate=function(self)self.playing=false end,Seek=function()end,Dispose=function()end}
 end,CreateScriptObject=function()return {SubscribeToEvent=function()end}end,Dispose=function()end}
end
Node=node
cache={GetResource=function()return {length=2}end,GetExistingResource=function()return {length=2}end,GetNumBackgroundLoadResources=function()return 0 end,ReleaseResource=function()end}
local Levels=require 'audio.AudioLevels';Levels.Init()
local State=require 'audio.GameMusicState'
local Voice=assert(load(MATCH))();local Music=assert(load(MVP))()
local battle={session={scene=node()},rules={state='prep'}}
local v=Voice.New(battle)
local drive={active=true,mapId='crater',input={locked=true}}
local function duck()return State.Resolve(drive,{},false).duck end
if PHASE=='all' or PHASE=='radio' then
check(not Levels.Speaking() and duck()==1,'radio initially idle')
v:Say('go');v:Next();check(Levels.Speaking()==(REF.radio.speaking[1].speaking>0) and duck()==.5,'MatchVoice starts source speaking duck')
v:Update(REF.radio.timerSeconds-.01);check(Levels.Speaking(),'source lead/tail speaking remains active')
v:Update(.01);check(Levels.Speaking()==(REF.radio.speaking[2].speaking>0) and duck()==1,'source radio timer releases speaking')
v:Reset();v:Say('go');v:Next();v:Reset();check(not Levels.Speaking(),'reset releases owned speaking')
local interrupt;for key,call in pairs(CONFIG['Combat/Radio.json'].calls)do if call.interrupt then interrupt=key;break end end
check(interrupt~=nil,'actual imported interrupt exists')
v:Say('go');v:Next();v:Say(interrupt);check(not Levels.Speaking(),'interrupt releases previous speaking')
v:Reset();v:Say('go');v:Next();input.focus=false;v:Update(0);check(not Levels.Speaking(),'focus loss releases speaking');input.focus=true
v:Reset();v:Say('go');v:Next();input.minimized=true;v:Update(0);check(not Levels.Speaking(),'minimize releases speaking');input.minimized=false
local other={};Levels.SetSpeaking(other,true);v:Reset();check(Levels.Speaking(),'reset preserves other speaking owner')
v:Say('go');v:Next();v:Dispose();check(Levels.Speaking(),'dispose preserves other speaking owner');Levels.SetSpeaking(other,false);check(not Levels.Speaking(),'dispose releases radio owner')
v:Dispose();check(not Levels.Speaking(),'repeated dispose stays idle')
end
local player={enabled=true,volume=.75};local m=Music.New(node(),player)
if PHASE=='all' or PHASE=='music' then
for _,row in ipairs(REF.music)do
 player.volume=row.volume;m:Update();check(math.abs(m.source.gain-row.gain)<1e-12,'MVP source music applies one 0.8 at '..row.volume)
 check(paused.VoxMvpMusic==row.paused,'MVP source zero volume pause')
end
player.volume=.75;player.enabled=false;m:Update();check(paused.VoxMvpMusic,'disabled MVP music pauses')
player.enabled=true;input.focus=false;m:Update();check(paused.VoxMvpMusic,'unfocused MVP music pauses')
input.focus=true;input.minimized=true;m:Update();check(paused.VoxMvpMusic,'minimized MVP music pauses')
input.minimized=false;m:Update();check(not paused.VoxMvpMusic,'focused enabled MVP music resumes')
end
local count=0
if PHASE=='all' or PHASE=='samples' then
for _,row in ipairs(REF.samples)do
 Levels.Set('sfx',row.volume);m:Play(row.id,row.strength);local s=m.slots[m.cursor]
 check(math.abs(s.gain-row.gain)<1e-12,'MVP source SFX master/unclipped cue '..row.id..' strength '..row.strength..' sfx '..row.volume)
 check(row.bus=='feedback','actual source MVP cue belongs to feedback')
 Levels.Set('sfx',.325);local expected=row.sourceCueGain*math.max(0,math.min(1,row.strength))*.325*.65/.6
 check(math.abs(s.gain-expected)<1e-12,'MVP live SFX volume applies shared master')
 count=count+1
end
end
input.focus=false;local cursor=m.cursor;m:Play('supply_choose');check(m.cursor==cursor,'unfocused MVP cue suppressed');input.focus=true
m:Dispose();m:Dispose()
return {sampleCases=count,musicCases=#REF.music,radioTimer=REF.radio.timerSeconds}
'''))

current=[(ROOT/p).read_text(encoding='utf8') for p in paths]
old=[(prior/p).read_text(encoding='utf8') for p in paths]
for p,sha in zip(paths,old_hashes):check(hashlib.sha256((prior/p).read_bytes()).hexdigest()==sha,'frozen prior SHA '+p)
if '--diagnose' in sys.argv:
    diagnostics=[]
    for phase in ['radio','music','samples']:
        try:run(*current,phase)
        except AssertionError as error:diagnostics.append({'case':'actual current '+phase,'failure':str(error)})
        else:raise AssertionError('Expected prior failure missing: '+phase)
    print(json.dumps({'result':'DIAGNOSED','diagnostics':diagnostics},indent=2))
    sys.exit(0)
result=run(*current)
negatives=[]
variants=[('frozen prior MatchVoice',[old[0],current[1]]),('frozen prior MvpMusic',[current[0],old[1]]),
 ('double music factor',[current[0],current[1].replace('Gain(p.volume)','Gain(p.volume)*.8')]),
 ('missing feedback bus',[current[0],current[1].replace(",0,'sfx','feedback'",'')]),
 ('clamped cue gain',[current[0],current[1].replace('cue.gain*math.max(0,math.min(1,gain or 1))*.65','math.min(1,cue.gain*math.max(0,math.min(1,gain or 1)))*.65')])]
for label,pair in variants:
    check(pair!=current,'negative changes candidate '+label)
    try:run(*pair)
    except AssertionError as error:negatives.append({'case':label,'rejected':str(error)})
    else:raise AssertionError('Negative escaped: '+label)
for phase in ['radio','music','samples']:
    try:run(*old,phase)
    except AssertionError as error:negatives.append({'case':'actual prior independent '+phase,'rejected':str(error)})
    else:raise AssertionError('Prior independent negative escaped: '+phase)
inputs=paths+['scripts/audio/MatchRadioDSP.lua','assets/Combat/MatchRadioDSP.json','scripts/audio/AudioLevels.lua','scripts/audio/MusicPlayer.lua','scripts/audio/GameMusicState.lua','assets/Combat/Radio.json','assets/Mvp/Cues.json','assets/Mvp/Beats.json','assets/UI/Music/Catalog.json','tools/migration/source-match-mvp-audio.cjs','tools/migration/source-game-audio.cjs','tools/migration/check-match-mvp-audio.py']
report={'result':'PASS','checks':checks,**result,'negativeControls':negatives,'baseline':reference['baseline'],'sourceHashes':reference['sourceHashes'],
 'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in inputs},
 'boundary':'CPU adapters execute actual methods; no GPU, rendered validation, DSP equivalence or listening acceptance.'}
(ROOT/'docs/migration/evidence/match-mvp-audio-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print(json.dumps(report,indent=2))
