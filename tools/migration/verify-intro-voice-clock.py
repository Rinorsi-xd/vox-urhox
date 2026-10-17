"""Actual frozen Vivi/onended flow versus production Lua with independent audio state."""
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
data = json.loads((ROOT / 'assets/Intro/Intro.json').read_text(encoding='utf-8'))
lua.globals().INTRO_DATA = table(data)
existing = ast.parse((ROOT / 'tools/migration/verify-intro-audio-tail.py').read_text(encoding='utf-8'))
fixture = next(node.value.args[0].value for node in existing.body if isinstance(node, ast.Assign)
               and any(isinstance(target, ast.Name) and target.id == 'checks' for target in node.targets))
setup = fixture.split('for _,case in ipairs(REFERENCE.masterTails)do')[0]
voice_fixture = setup + '''
package.loaded['urhox-libs/UI']={GetFocus=function()end};package.loaded['core.Coord']={}
for _,name in ipairs({'ui.IntroTypography','app.ResourceGate','ui.IntroPage','intro.IntroImpact','intro.IntroSortie'})do package.loaded[name]={}end
local Session=require 'intro.IntroSession'
local function NewVoice()
 local value=Audio.New({audio={},durations={}})
 value.sounds.vo_v01=Sound('voice-clock');value.sounds.vo_v01.length=2
 return value
end
local function Dialogue(value,wait)
 local I=setmetatable({active=true,audio=value,host={},stage='reality',shot='comms',time=0,age=0,log={},data=INTRO_DATA},{__index=Session})
 I.thread=coroutine.create(function()I:Vivi('v01','talk',wait);I.done=true end)
 local ok,err=coroutine.resume(I.thread);assert(ok,err);return I
end
for _,case in ipairs(REFERENCE.voiceClock)do
 local value=NewVoice();if case.missing then value.sounds={}end
 local I=Dialogue(value,case.wait==true)
 Check(not I.waitingAdvance,'next prompt starts hidden: '..case.name)
 local startsWithToken=I.lineVoiceToken~=nil
 for _,row in ipairs(case.samples)do
  if row.tap then I:Advance()end
  if row['end']then value.voice:StopImmediate()end
  I:Update(row.dt,true)
  Check((I.done==true)==row.complete,'frozen real Vivi completion differs: '..case.name..' at '..row.age)
  Check((I.waitingAdvance==true)==(row.nextVisible and not row.complete),'frozen source post-voice waiting phase differs: '..case.name..' at '..row.age)
  if I.done then Check(I.lineVoiceToken==nil,'completed line clears source token')end
 end
 Check(startsWithToken==(case.missing~=true),'current dialogue exposes only its own prepared audio token')
 value:Dispose()
end
local value=NewVoice();local duration,token=value:Voice('vo_v01');local original=value.voice
Check(duration==2 and value:IsVoicePlaying(token),'prepared voice returns backward-compatible duration and live generation')
value:Update(5,true)
Check(original.playing and value:IsVoicePlaying(token),'dt exceeding duration cannot truncate a still-playing native voice')
Check(value.voiceUntil>0 and value.duckFade.target==.24,'still-playing voice keeps natural duck membership after estimated deadline')
original.playing=false;original.fadingOut=true
Check(value:IsVoicePlaying(token),'native fading-out is busy although IsPlaying is false')
local _,nextToken=value:Voice('vo_v01');local nextSource=value.voice
Check(nextSource~=original and #value.voices==2,'native fade-out cannot be selected as a reusable source')
original.fadingOut=false;value:Update(0,true)
Check(value:IsVoicePlaying(nextToken)and value.duckFade.target==.24,'previous natural completion cannot unduck a newer live voice')
nextSource:StopImmediate();value:Update(0,true)
Check(value.voiceUntil==0 and value.duckFade.target==.55,'last natural completion restores duck without waiting for dt deadline')
local _,reusedToken=value:Voice('vo_v01')
Check(value.voice==original and reusedToken~=token,'finished slot reused with a fresh generation')
Check(not value:IsVoicePlaying(token)and value:IsVoicePlaying(reusedToken),'stale token cannot wait on a replacement voice')
value:StopVoice()
Check(value.voiceUntil==0 and value.duckFade.target==.55,'manual stop immediately releases natural duck membership')
local fading=value.voice;local _,afterStop=value:Voice('vo_v01')
Check(value.voice~=fading,'manual fade tail survives a new voice')
value:Update(.11,true)
Check(not fading.playing and value:IsVoicePlaying(afterStop),'old stop tail cannot stop new voice')
Check(value.duckFade.target==.24,'old manually stopped tail cannot unduck newer voice')
value:Dispose();Check(not value:IsVoicePlaying(afterStop),'disposed owner rejects token before reading native state')
Check(value:Voice('vo_v01')==0,'disposed owner cannot start a voice')
local missing=NewVoice();missing.sounds={}
local noDuration,noToken=missing:Voice('vo_v01')
Check(noDuration==0 and noToken==nil and not missing:IsVoicePlaying(noToken),'unprepared resource completes its audio promise immediately')
missing.sounds.vo_v01=Sound('empty');missing.sounds.vo_v01.length=0
Check(missing:Voice('vo_v01')==0,'empty resource never starts a pending native voice')
missing:Dispose()
local paused=NewVoice();local I=Dialogue(paused,false)
I:Update(1.9,true);local at=I.lineAge;paused.voice:StopImmediate()
I:Update(10,false)
Check(I.lineAge==at and not I.done,'focus suspension cannot resume dialogue even when audio has ended')
I:Update(0,true);Check(I.done,'focus restoration observes completed native audio without waiting for more dt')
paused:Dispose()
local cancelled=NewVoice();local C=Dialogue(cancelled,false)
C.active=false;cancelled:Dispose();local ok,err=coroutine.resume(C.thread)
Check(ok and coroutine.status(C.thread)=='dead','cancellation during typing does not query disposed native state: '..tostring(err))
local stopped=NewVoice();local S=Dialogue(stopped,false)
S:Update(1.9,true);S.active=false;stopped:Dispose();ok,err=coroutine.resume(S.thread)
Check(ok and coroutine.status(S.thread)=='dead','cancellation during voice wait cannot strand coroutine: '..tostring(err))
local marked=NewVoice();local K=Dialogue(marked,true)
K:Update(1.9,true);marked.voice:StopImmediate();K:Update(0,true)
Check(K.waitingAdvance and K.lineVoiceToken~=nil,'post-voice prompt retains current token until line ends')
K:Mark('contract');Check(not K.waitingAdvance and K.lineVoiceToken==nil,'shot change clears prompt and voice token')
K.waitingAdvance=true;K.lineVoiceToken=1;K.gate={Cancel=function()end};K.page={Close=function()end};input={};MM_ABSOLUTE='absolute'
K:Dispose();Check(not K.waitingAdvance and K.lineVoiceToken==nil,'Session Dispose clears prompt and token before releasing audio')
local choice=NewVoice();local Q=setmetatable({active=true,audio=choice,shot='comms',choosing=true,time=12.5},{__index=Session})
Check(Q:Choose(2)and Q.choiceAt==12.5,'accepted choice records precise animation clock without changing its wait')
Q.time=13;Check(not Q:Choose(1)and Q.choiceAt==12.5,'duplicate choice cannot restart option exit clock')
choice:Dispose()
local say=NewVoice();local A=setmetatable({active=true,audio=say,time=0,data={caps={},durations={}},log={}},{__index=Session})
A.thread=coroutine.create(function()A:Say('v01',.15);A.done=true end)
assert(coroutine.resume(A.thread));say.voice:StopImmediate();A.time=1.9;assert(coroutine.resume(A.thread))
Check(not A.done,'Say retains source animation-clock wait even when audio naturally ends early')
A.time=2.16;assert(coroutine.resume(A.thread));Check(A.done,'Say retains duration plus original subtitle tail')
say:Dispose()
return checks
'''
negative = []
old_root = ROOT / '.tmp/outgame-cached-1792101454346/scripts'
for modules in [('intro.IntroSession',), ('audio.IntroAudio', 'intro.IntroSession')]:
    old = LuaRuntime(unpack_returned_tuples=True)
    def old_table(value):
        if isinstance(value, dict):
            return old.table_from({key: old_table(item) for key, item in value.items()})
        if isinstance(value, list):
            return old.table_from([old_table(item) for item in value])
        return value
    old.globals().REFERENCE = old_table(reference)
    old.globals().INTRO_DATA = old_table(data)
    old_hashes = {}
    for module in modules:
        path = module.replace('.', '/') + '.lua'
        raw = (old_root / path).read_bytes()
        old_hashes[path] = hashlib.sha256(raw).hexdigest()
        old.globals().OLD_SOURCE = raw.decode('utf-8')
        old.execute('local chunk=assert(load(OLD_SOURCE));package.preload[' + json.dumps(module) + ']=chunk')
    try:
        old.execute(voice_fixture)
    except Exception as error:
        assert 'frozen real Vivi completion differs: natural-before-duration' in str(error), str(error)
        negative.append({'manifest': 'manifest-9b1ad62f.json', 'hashes': old_hashes,
                         'observedFailure': str(error).split('\n')[0]})
    else:
        raise AssertionError('Historical duration-only voice wait unexpectedly passed')
checks = lua.execute(voice_fixture)
paths = ['scripts/audio/IntroAudio.lua', 'scripts/intro/IntroSession.lua',
         'tools/migration/source-intro-audio.cjs']
result = {
    'result': 'PASS', 'checks': checks, 'sourceCommit': reference['commit'],
    'sourceHashes': reference['sourceHashes'], 'sourceCases': reference['voiceClock'],
    'historicalNegativeControls': negative,
    'productionHashes': {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths},
    'apiReferenceHashes': {'.emmylua/SoundSource.d.lua': hashlib.sha256((ROOT / '.emmylua/SoundSource.d.lua').read_bytes()).hexdigest()},
    'boundary': 'Actual frozen IntroStory.vivi and IntroAudio.voice execute through vm.SourceTextModule. Actual production Lua Session.Vivi/Advance/Update/Say and IntroAudio execute in Lua5.4. Independent native source completion, fade and pause adapters, not a real engine/audio/GPU run. Does not establish audible continuity, exact native callback time or mobile performance.'
}
out = ROOT / 'docs/migration/evidence/intro-voice-clock-offline.json'
out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': result['result'], 'checks': checks, 'evidence': str(out)}))
