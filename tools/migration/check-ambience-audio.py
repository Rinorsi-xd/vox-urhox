"""Run the production ambience module and original mixer against frozen H5 cases."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

module = ROOT / 'scripts/audio/GameAmbience.lua'
config = json.loads((ROOT / 'assets/Combat/AmbienceSounds.json').read_text(encoding='utf-8'))
cases = json.loads((ROOT / 'tools/migration/source-ambience-audio.json').read_text(encoding='utf-8'))
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
assert config['baseline'] == cases['baseline'] == baseline['commit']
for cue in config['cues'].values():
    actual = (ROOT / 'assets' / cue['path']).read_bytes()
    assert hashlib.sha256(actual).hexdigest() == cue['sha256'] == baseline['files'][cue['source']]['sha256']
    assert len(actual) == cue['bytes']


def run(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().DATA = lua.table_from(config, recursive=True)
    lua.execute('''
        package.path='scripts/?.lua;'..package.path
        package.loaded['core.ResourceData']={Read=function()return DATA end}
        requests={};sounds={};backgrounds={};releases={};sources={};wall=0;checks=0
        Time={GetSystemTime=function()return wall end}
        local function Source()
            local s={playing=false}
            function s:Play(sound,freq,gain,pan) self.sound=sound;self.frequency=freq;self.gain=gain;self.panning=pan;self.playing=true end
            function s:StopImmediate()self.playing=false end
            function s:Dispose()self.disposed=true end
            sources[#sources+1]=s;return s
        end
        function Scene()
            local scene={}
            function scene:CreateChild()return self end
            function scene:CreateComponent()return Source()end
            function scene:Dispose()self.disposed=true end
            return scene
        end
        backend={GetExistingResource=function(_,_,p)return sounds[p]end,
            GetResource=function()error('Synchronous sound load forbidden')end,
            BackgroundLoadResource=function(_,_,p)backgrounds[#backgrounds+1]=p;return false end,
            ReleaseResource=function(_,_,p)releases[#releases+1]=p end}
        package.loaded['app.ResourceGate']={New=function()
            return {Cancel=function(self)self.cancelled=(self.cancelled or 0)+1 end,
                Start=function(self,paths,callback)requests[#requests+1]={paths=paths,callback=callback}end}
        end}
        Levels=require('audio.AudioLevels');Levels.Init(nil)
        function Check(ok,label)checks=checks+1;assert(ok,label)end
        function Near(a,b,label)Check(math.abs(a-b)<1e-9,label)end
    ''')
    lua.globals().M = lua.execute(source)
    for case in cases['cases']:
        got = lua.globals().M.Resolve(lua.table_from(case['state'], recursive=True))
        assert got == case['chosen'], (got, case)
    return lua.execute('''
        local function State(active,map,firing)
            return {drive={active=active,mapId=map,input={locked=true},firing=firing},shell={}}
        end
        local hangar=State(false);local crater=State(true,'crater');local mine=State(true,'salvage')
        local a=M.New(backend)
        Check(#requests==0 and #backgrounds==0,'New does not download or decode any scene')
        a:Update(.1,{disabled=true,drive={}},true)
        Check(#requests==0,'disabled startup does not prepare ambience')
        a:Update(.1,hangar,true)
        Check(#requests==1 and #requests[1].paths==1 and requests[1].paths[1]==DATA.cues.amb_hangar.path,'only chosen scene downloads')
        local stale=requests[1].callback
        a:Update(.1,crater,true)
        Check(#requests==2 and a.pending.id=='amb_crater','switch cancels old preparation')
        stale(true);Check(not a.pending.downloaded,'stale callback cannot ready replacement')
        requests[2].callback(true)
        Check(#backgrounds==0 and #sources==0,'callback does not decode or play under native lock')
        a:Update(.1,crater,true);a:Update(.1,crater,true)
        Check(#backgrounds==1 and #sources==0,'one asynchronous load, false already-queued return still polls')
        sounds[DATA.cues.amb_crater.path]={length=19.5}
        a:Update(.1,crater,true)
        Check(#sources==1 and a.current.id=='amb_crater' and a.current.sound.looped,'ready sound loops')
        Check(a.current.source.frequency==0,'absolute frequency zero preserves original playback rate')
        local first=.16*(1-math.exp(-.1/.5))
        Near(a.current.amount,first,'original attack tau .5')
        Near(a.current.source.gain,first*.65/.6,'original explicit sample sfx master')
        a:Update(.1,State(true,'crater',true),true)
        local second=first+(.16*.6-first)*(1-math.exp(-.1/.5))
        Near(a.current.amount,second,'firing reduces ambient target to .6')
        local context=Levels.MixContext(.2,true)
        Near(a.current.source.gain,second*.65/.6*context,'briefing ducks ambience through shared bus')
        Levels.Set('sfx',.325)
        Near(a.current.source.gain,second*.5*.65/.6*context,'live sfx slider updates loop')
        local source=a.current.source
        a:Update(.2,mine,true)
        Check(not a.current and a.slots[1].releaseAge==.2,'scene switch releases old key immediately')
        Near(a.slots[1].amount,second*math.exp(-.2/.25),'release tau .25 retained')
        a:Update(1.05,mine,true)
        Check(#a.slots==0 and source.disposed,'five tau release disposes source')
        local cb=requests[#requests].callback
        a:Update(.1,mine,false);cb(true)
        Check(not a.pending and #a.slots==0,'focus loss cancels pending and silences immediately')
        a:Update(.1,mine,true);requests[#requests].callback(false,'fixture failure')
        a:Update(.1,mine,true)
        local count=#requests;a:Update(1,mine,true)
        Check(#requests==count and not a.pending,'failure backoff avoids retry per frame')
        a:Update(5,mine,true);Check(#requests==count+1,'retry selected scene after backoff')
        requests[#requests].callback(true);sounds[DATA.cues.amb_mine.path]={length=19.5};a:Update(.1,mine,true)
        local active=a.current.source;a:Update(.1,mine,false)
        Check(not active.playing and active.disposed and #a.slots==0,'focus loss stops live loop')
        a:Dispose();a:Dispose();Check(a.scene.disposed,'owned audio scene disposed idempotently')
        local before=#requests;a:Update(1,hangar,true);Check(#requests==before,'disposed owner never restarts')
        local b=M.New(backend)
        for _,cue in pairs(DATA.cues)do sounds[cue.path]={length=19.5}end
        for i=1,30 do
            local state=i%2==0 and crater or hangar
            b:Update(.001,state,true);requests[#requests].callback(true);b:Update(.001,state,true)
            Check(#b.slots<=8,'rapid scene switches keep bounded voices')
        end
        b:Dispose()
        Levels.Init(nil)
        local quiet=M.New(backend)
        quiet:Update(.1,hangar,true);requests[#requests].callback(true);quiet:Update(10,hangar,true)
        local hangarTarget=.14*.5*(1-math.exp(-10/.5))
        Near(quiet.current.amount,hangarTarget,'requested hangar ambience reduced by half')
        Near(quiet.current.source.gain,hangarTarget*.65/.6,'hall reduction reaches actual source gain')
        Levels.Set('sfx',.325)
        Near(quiet.current.source.gain,hangarTarget*.5*.65/.6,'hall trim retains live sfx control')
        quiet:Dispose()
        for _,s in ipairs(sources)do Check(s.disposed and not s.playing,'all owned voices retired')end
        local app={mode='hangar',scene={},music={unlocked=true},loader={state='ready'}}
        Check(M.Resolve(M.FromApp(app,{}))=='amb_hangar','app default hangar')
        app.lobby='salvage';Check(M.Resolve(M.FromApp(app,{}))=='amb_warehouse','app salvage lobby warehouse')
        app.lobby=nil;app.warehouse={ready=true};Check(M.Resolve(M.FromApp(app,{}))=='amb_warehouse','actual warehouse stage')
        app.warehouse=nil;app.mode='trial';app.trial={map={id='salvage'},pointer={captured=true}}
        Check(M.Resolve(M.FromApp(app,{}))=='amb_mine','app mine')
        app.trial.pointer.captured=false;Check(M.Resolve(M.FromApp(app,{}))==nil,'unlocked combat pauses ambience')
        app.trial.pointer.captured=true;app.trial.intro={done=false};Check(M.Resolve(M.FromApp(app,{}))==nil,'match intro masked')
        app.trial.intro=nil;app.trial.story={};app.trial.combat={rules={finished=true}}
        Check(M.Resolve(M.FromApp(app,{}))==nil,'finished story masked')
        app.trial.story=nil;app.trial.endless={run={state='editing'}};app.trial.pointer.captured=false
        Check(M.Resolve(M.FromApp(app,{}))=='amb_hangar','paused edit world uses hangar')
        app.trial.endless.run.state='over';Check(M.Resolve(M.FromApp(app,{}))==nil,'endless over masked')
        app.trial=nil;app.mode='hangar';app.loadingFlow={active=true}
        Check(M.Resolve(M.FromApp(app,{}))==nil,'loading transition masked')
        app.loadingFlow=nil;app.loader.state='loading';Check(M.Resolve(M.FromApp(app,{}))==nil,'scene construction masked')
        app.loader.state='ready';app.opening={active=true};Check(M.Resolve(M.FromApp(app,{}))==nil,'opening own audio masked')
        app.opening=nil;app.music.unlocked=false;Check(M.Resolve(M.FromApp(app,{}))==nil,'gesture unlock retained')
        return checks
    ''')


source = module.read_text(encoding='utf-8')
checks = run(source)
negative = []
for label, candidate in [
    ('wrong-attack', source.replace('/cue.attack)', '/.08)')),
    ('missing-hangar-trim', source.replace('HANGAR_GAIN_SCALE=.5', 'HANGAR_GAIN_SCALE=1')),
    ('missing-scene-cancellation', source.replace('self.chosen=id;self.retryAt=0;self:CancelPending();self:ReleaseCurrent()', 'self.chosen=id;self.retryAt=0;self:ReleaseCurrent()')),
    ('lost-ambience-bus', source.replace("0,'sfx',cue.bus)", "0,'sfx',nil)")),
]:
    assert candidate != source
    try:
        run(candidate)
    except Exception as error:
        negative.append({'name': label, 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: '+label)
report = {'result': 'PASS', 'baseline': baseline['commit'], 'sourceResolverCases': len(cases['cases']),
          'checks': checks, 'originalSamples': len(config['cues']), 'originalSampleBytes': sum(c['bytes'] for c in config['cues'].values()),
          'negativeControls': negative, 'productionSha256': hashlib.sha256(module.read_bytes()).hexdigest(),
          'productionHashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
              'scripts/audio/GameAmbience.lua', 'scripts/app/HangarApp.lua', 'scripts/audio/AudioLevels.lua']},
          'resources': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
              'assets/Combat/AmbienceSounds.json', *('assets/'+c['path'] for c in config['cues'].values())]},
          'inputs': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
              'tools/migration/check-ambience-audio.py', 'tools/migration/import-ambience-audio.mjs',
              'tools/migration/source-ambience-audio.json']},
          'baselineManifestSha256': hashlib.sha256((ROOT / 'docs/migration/outgame-baseline.json').read_bytes()).hexdigest(),
          'toolSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'boundary': 'Actual Lua production module and mixer under controlled download/audio backend; original WAV SHA256 and H5 resolver parity. No actual Web/native listening, scene continuity or mobile performance acceptance.'}
(ROOT / 'docs/migration/evidence/ambience-audio-offline.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, indent=2))
