"""Frozen JS sound transitions against actual Lua audio/session/pointer handlers."""
import ast
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
    ['node', '--experimental-vm-modules', 'tools/migration/source-intro-audio.cjs'], encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)


def table(value):
    if isinstance(value, dict):
        return lua.table_from({key: table(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(item) for item in value])
    return value


lua.globals().REFERENCE = table(reference)
existing = ast.parse((ROOT / 'tools/migration/verify-intro-audio-tail.py').read_text(encoding='utf-8'))
fixture = next(node.value.args[0].value for node in existing.body if isinstance(node, ast.Assign)
               and any(isinstance(target, ast.Name) and target.id == 'checks' for target in node.targets))
setup = fixture.split('for _,case in ipairs(REFERENCE.masterTails)do')[0]
checks = lua.execute(setup + '''
local function Blank()
 wall=0
 Levels.Set('voice',.6);Levels.Set('sfx',.65);Levels.Set('music',.75)
 local value=Audio.New({audio={},durations={}})
 for _,id in ipairs({'vo_test','bgm_test','sfx_tv_cut','sfx_scribble','sfx_heartbeat','sfx_alarm','sfx_confirm','sfx_crt_on'})do value.sounds[id]=Sound(id)end
 value.sounds.vo_test.length=2
 return value
end
for _,case in ipairs(REFERENCE.transitions)do
 local value=Blank();local kind=case.kind;local source
 if kind:sub(1,5)=='voice'then
  value:Voice('vo_test');source=value.voice;value:Update(case.start,true);value:StopVoice()
  if kind=='voice-overlap'then
   value:Voice('vo_test');Check(value.voice~=source,'next voice owns a different source while previous short fade plays')
   Check(#value.voices==2,'voice overlap preserves both original sources')
  end
 elseif kind:sub(1,5)=='music'then
  value:Music('bgm_test',{vol=.75,fade=1.2});source=value.music[value.musicIndex].source
  value:Update(case.start,true);value:StopMusic(kind=='music-zero'and 0 or .6)
 else
  source=value:Sfx(kind=='tvcut'and'tv_cut'or'scribble',{vol=kind=='tvcut'and .5 or .4,loop=kind=='scribble',
   stopAfter=kind=='tvcut'and .45 or nil,stopFade=kind=='tvcut'and .15 or nil})
  wall=case.start*1000;value:Update(case.start,true)
  if kind=='scribble'then value:StopSfx(source,.1)end
 end
 for _,row in ipairs(case.events)do
  wall=(case.start+row.elapsed)*1000
  value:Update(case.start+row.elapsed-value.time,true)
  Near(source.gain,row.level,'source '..kind..' gain at '..row.elapsed)
  Check((not source.playing)==row.stopped,kind..' exact original stop tail at '..row.elapsed)
  if kind=='voice-overlap'then Near(value.voice.gain,row.currentLevel,'new voice unaffected by old voice fade')end
 end
 value:Dispose()
end
local paused=Blank();paused:Voice('vo_test');local voice=paused.voice;paused:StopVoice()
paused:Update(.04,false);Near(voice.gain,.9,'focus suspension freezes voice fade')
paused:Update(.04,true);Near(voice.gain,.45,'resumed voice continues original fade')
Levels.Set('voice',.3);Near(voice.gain,.225,'slider retains current voice stop envelope')
paused:Update(.061,true);Check(not voice.playing,'resumed voice closes only after fade plus twenty milliseconds')
paused:Dispose()
local cut=Blank();local old,token=cut:Sfx('tv_cut',{vol=.5,stopAfter=.45,stopFade=.15})
wall=450;cut:Update(.45,false);Check(old.playing,'hidden delayed cut does not consume audio clock')
Check(cut.sources[1].stopFade and cut.sources[1].fadeWallAt==nil,'source wall timer schedules fade while focused audio clock is suspended')
wall=500;cut:Update(0,true);Check(old.playing and old.gain>0,'pending cut resumes from paused fade start')
wall=550;cut:Update(.05,true);Check(old.playing and old.gain>0,'resumed cut advances its original audio fade')
cut:StopSfx(old,.1,token);cut:Update(.05,true);Check(old.gain>0,'explicit stop replaces pending stop from current level')
cut:Dispose();Check(not old.playing,'cancellation immediately stops pending delayed fade')
local reuse=Blank();local prior,priorToken=reuse:Sfx('scribble',{vol=.4,loop=true});reuse:StopSfx(prior,.1,priorToken)
prior:StopImmediate();local pending=reuse:Sfx('tv_cut',{vol=.5})
Check(prior~=pending,'non-playing source with an owned pending fade is reserved')
reuse:Update(.121,true);local nextSource,nextToken=reuse:Sfx('tv_cut',{vol=.5})
Check(prior==nextSource and priorToken~=nextToken,'fixture reuses only a fully completed fading slot')
Check(not reuse:StopSfx(prior,.1,priorToken),'late signature stop cannot stop a reused slot')
reuse:Update(.3,true);Check(nextSource.playing,'slot reuse removes prior stop deadline');reuse:Dispose()
package.loaded['urhox-libs/UI']={GetFocus=function()end};package.loaded['core.Coord']={}
for _,name in ipairs({'ui.IntroTypography','app.ResourceGate','ui.IntroPage','intro.IntroImpact','intro.IntroSortie'})do package.loaded[name]={}end
local Session=require 'intro.IntroSession'
for _,row in ipairs(REFERENCE.heartbeat)do
 local sound=Blank();local source,token=sound:Sfx('heartbeat',{vol=.5,loop=true})
 local I=setmetatable({active=true,audio=sound,host={},stage='audit',time=0,age=0,deciding=true,holding=true,
  holdProgress=row.progress,holdIdle=0,heart=source,heartToken=token,heartFrequency=source.frequency},{__index=Session})
 I:Update(0,true);Near(source.frequency,48000*row.rate,'actual Session applies frozen source heartbeat rate')
 I:Update(.1,false);Near(source.frequency,48000*row.rate,'focus pause cannot advance hold or heartbeat pitch')
 sound:Dispose()
end
local cues={};local comms=Blank();local original=comms.Sfx
comms.Sfx=function(self,id,opt)cues[#cues+1]={id=id,opt=opt};return original(self,id,opt)end
local I=setmetatable({active=true,ready=true,clicked=true,part='',time=0,age=0,log={},host={},audio=comms,
 Ad=function()end,Wait=function()return true end,Vivi=function()error('COMMS_CUE_CAPTURED')end},{__index=Session})
local ok,err=pcall(I.Run,I);Check(not ok and tostring(err):find('COMMS_CUE_CAPTURED'),'actual Run reaches first real comms line')
local confirms=0
for _,cue in ipairs(cues)do if cue.id=='confirm'then confirms=confirms+1;Near(cue.opt.vol,.6,'original comms connect cue volume')end end
Check(confirms==1,'actual Run emits one comms connect cue');comms:Dispose()
local Page
local UI={Widget={Extend=function()Page={};return Page end},GetScale=function()return 1 end}
package.loaded['urhox-libs/UI']=UI;graphics={GetDPR=function()return 1 end}
for _,name in ipairs({'ui.SourceDraw','ui.IntroFrame','ui.SourceParagraph','ui.WorkshopPaint','urhox-libs/UI/Core/ImageCache','ui.IntroContractLayout','ui.IntroOpacity','ui.IntroGateMotion','ui.IntroGateFx'})do package.loaded[name]={}end
package.loaded['ui.IntroPage']=nil
require 'ui.IntroPage'
local signing=Blank();local owner={shot='contract',strokes={},ink=0,audio=signing}
local page=setmetatable({owner=owner,buttons={},pointers={},signatureRect={x=0,y=0,w=100,h=100},k=1},{__index=Page})
page:OnPointerDown({pointerId=7,pointerType='touch',x=10,y=10});local scribble=page.scribble
page:OnPointerCancel({pointerId=7});Check(scribble.playing and page.scribble==nil,'actual pointer cancel detaches handle but preserves short sound tail')
page:OnPointerUp({pointerId=7});signing:Update(.05,true)
Near(scribble.gain,.9*.4*math.min(2,10^((-12+30.1)/20))*.65*.5,'actual pointer release retains original 100ms fade')
signing:Update(.071,true);Check(not scribble.playing,'signature sound ends after original fade and twenty milliseconds')
signing:Dispose()
return checks
''')
paths = ['scripts/audio/IntroAudio.lua', 'scripts/audio/IntroAudioTail.lua', 'scripts/audio/AudioLevels.lua',
         'scripts/intro/IntroSession.lua', 'scripts/ui/IntroPage.lua']
report = {
    'result': 'PASS', 'checks': checks, 'sourceCommit': reference['commit'], 'sourceHashes': reference['sourceHashes'],
    'productionHashes': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths},
    'sourceTransitions': reference['transitions'], 'sourceHeartbeat': reference['heartbeat'],
    'boundary': 'Actual frozen JS IntroAudio playback/stop automation and heartbeat statement; actual Lua IntroAudio, IntroSession Update/Run and IntroPage pointer handlers. Controlled native audio/scene and UI adapters. Covers overlapping interrupted voice tails, partial and zero-duration music stops, delayed television cut, signature pointer cancel/up, focus suspension, sliders, token reuse and Dispose. Television cut wall timer still schedules its fade when focus pauses audio. Gain envelopes use the existing focused Lua audio clock, not exact native AudioContext scheduling under clamped dt. No native DSP/decoding/output, complete rendered opening, Web continuity or mobile acceptance.'}
out = ROOT / 'docs/migration/evidence/intro-mix-transitions-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key not in ('sourceTransitions', 'sourceHeartbeat')}, indent=2))
