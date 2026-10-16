"""Check the current natural-opening QA tools without a browser or GPU."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def node(*args):
    result=subprocess.run(['node',*args],cwd=ROOT,text=True,capture_output=True,check=True)
    return result.stdout

meter=json.loads(node('tools/migration/check-intro-audio-meter.cjs'))
assert meter['result']=='PASS' and meter['checks']==27
syntax=[]
for relative in ['tools/migration/check-intro-natural-web.cjs','tools/migration/audit-unified-snapshot.cjs',
                 'tools/migration/trace-resource-downloads.cjs','tools/migration/summarize-intro-downloads.cjs']:
    node('--check',relative)
    syntax.append({'path':relative,'result':'PASS','parser':'node --check'})
probe='tools/migration/probe-outgame-web.lua'
lua=LuaRuntime(unpack_returned_tuples=True)
compiled=lua.eval('load')((ROOT/probe).read_text(encoding='utf-8'),'@'+probe)
assert compiled is not None and not isinstance(compiled,tuple),compiled
syntax.append({'path':probe,'result':'PASS','parser':'Lua 5.4 load, not executed'})
source=(ROOT/probe).read_text(encoding='utf-8')
helper=source[source.index('local function AssetReleaseState(app)'):source.index('local function ResourceStats(app)')]
release_checks=lua.execute('''
local checks=0
local function check(value) assert(value);checks=checks+1 end
local background=0
cache={GetNumBackgroundLoadResources=function() return background end}
require=function() error('The snapshot must not lazy-load production modules') end
package.loaded['core.CollectionCycle']=nil
'''+helper+'''
local app={loader={state='ready'},pendingAssetRelease=function() end,assetReleaseFrames=0,
    assetReleaseIncremental=true,assetReleaseEpoch=4,
    opening={host={state={assetReleasePending=true}}}}
local s=AssetReleaseState(app)
check(s.appPendingAssetRelease and s.hostAssetReleasePending and s.eligible)
check(s.collectionCycle==false and s.collectionFencePassed==false)
check(s.framesElapsed and s.assetReleaseFrames==0 and s.assetReleaseIncremental)
check(s.guards.running and s.guards.noOpeningRetirements and s.guards.loaderNotLoading and s.guards.backgroundEmpty)
package.loaded['core.CollectionCycle']={State=function() return {epoch=4,active=true,previousMode='generational',stepping=false} end}
s=AssetReleaseState(app)
check(s.collectionCycle.epoch==4 and s.collectionCycle.active and s.collectionCycle.previousMode=='generational')
check(not s.collectionFencePassed and s.assetReleaseEpoch==4)
package.loaded['core.CollectionCycle'].State=function() return {epoch=5,active=false,previousMode=false,stepping=false} end
check(AssetReleaseState(app).collectionFencePassed)
app.openingRetirements={}
s=AssetReleaseState(app)
check(not s.eligible and not s.guards.noOpeningRetirements and s.openingRetirementQueuePresent and s.openingRetirementJobs==0)
app.openingRetirements={{}}
check(AssetReleaseState(app).openingRetirementJobs==1)
app.openingRetirements=nil
app.loader.state='loading'
s=AssetReleaseState(app)
check(not s.eligible and not s.guards.loaderNotLoading and s.loaderState=='loading')
app.loader.state='ready';background=3
s=AssetReleaseState(app)
check(not s.eligible and not s.guards.backgroundEmpty and s.backgroundLoadResources==3)
background=0;app.stopped=true
s=AssetReleaseState(app)
check(not s.eligible and not s.guards.running and s.stopped)
app.stopped=false;app.assetReleaseFrames=2
s=AssetReleaseState(app)
check(s.eligible and not s.framesElapsed and s.assetReleaseFrames==2)
app.pendingAssetRelease=nil
s=AssetReleaseState(app)
check(not s.appPendingAssetRelease and s.hostAssetReleasePending and not s.eligible)
app.opening=nil;app.pendingAssetRelease=function() end
s=AssetReleaseState(app)
check(s.appPendingAssetRelease and not s.hostPresent and not s.hostAssetReleasePending and s.eligible)
app.assetReleaseIncremental=false;app.assetReleaseEpoch=nil
s=AssetReleaseState(app)
check(not s.assetReleaseIncremental and not s.collectionFencePassed)
app.loader=nil
check(not AssetReleaseState(app).eligible)
s=AssetReleaseState(nil)
check(not s.appPendingAssetRelease and not s.eligible and not s.guards.running)
return checks
''')
header=source[:source.index('VOX_SKIP_TUTORIAL=true')]
lua.globals().AUDIO_GATE_SOURCE=(ROOT/'scripts/app/ResourceGate.lua').read_text(encoding='utf-8')
audio_checks=lua.execute('''
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local wall=100;Time={GetSystemTime=function()return wall end}
local requests,cancelled,nativeCalls={},{},0
local backend={Exists=function()nativeCalls=nativeCalls+1;return false end,
    CancelDownloadGroup=function(_,group)cancelled[#cancelled+1]=group end,
    DownloadResources=function(_,paths,done)
        nativeCalls=nativeCalls+1;requests[#requests+1]={paths=paths,done=done};return #requests
    end}
local Gate=assert(load(AUDIO_GATE_SOURCE))()
'''+header+'''
local music={slots={{gate=Gate.New(backend)}}}
function music:PreparePending(mode)
    local slot=self.slots[1]
    if mode=='queue' then slot.preparation.queued=true
    elseif mode=='ready' then slot.sound={};slot.source={};slot.preparation=nil;self.pending=nil end
    return 'first',nil,'third',false
end
local ambience={gate=Gate.New(backend),slots={}}
function ambience:Prepare(mode)
    if mode=='queue' then self.pending.queued=true
    elseif mode=='ready' then self.current={id=self.pending.id,sound={},source={}};self.pending=nil end
end
local app={music=music,ambience=ambience}
EnsureUpdateTiming(app)
local slot=music.slots[1];slot.track={id='test-track'};music.pending=1
slot.preparation={}
slot.gate:Start({'Sounds/Music/test.mp3'},function(ok)slot.preparation.downloaded=ok end)
ObserveAudioPreparation(app)
local s=AudioPreparationState(app);local r=s.events[1]
check(r.requestWall==100 and r.kind=='music' and r.group==1,'real ResourceGate request path/time/group')
check(s.music.pending and s.music.paths[1]=='Sounds/Music/test.mp3','pending music actual path')
check(r.id=='test-track' and r.pending and not r.queuedObservedWall and not r.readyObservedWall,'no invented queue/readiness')
wall=120;requests[1].done(true,0)
check(r.downloadCompleteWall==120 and r.downloadOK and slot.preparation.downloaded,'callback wall and original behavior')
wall=130;local a,b,c,d=music:PreparePending('queue')
check(a=='first' and b==nil and c=='third' and d==false,'wrapped prepare retains returns')
check(r.queuedObservedWall==130 and not r.readyObservedWall,'queue upper bound after actual method')
wall=160;music:PreparePending('ready')
check(r.readyObservedWall==160 and r.sourceObservedWall==160 and not r.pending,'ready/source observed after actual method')
check(not AudioPreparationState(app).music.pending,'completed music no longer pending')
check(nativeCalls==2,'observer does not query or load resources')
wall=200;ambience.pending={id='amb_hangar'}
ambience.gate:Start({'Sounds/Ambience/amb_hangar_a.wav'},function(ok)ambience.pending.downloaded=ok end)
ObserveAudioPreparation(app);r=audioPreparation.events[2]
check(r.kind=='ambience' and r.id=='amb_hangar' and r.requestWall==200,'actual ambience request identity')
check(AudioPreparationState(app).ambience.paths[1]=='Sounds/Ambience/amb_hangar_a.wav','pending ambience actual path')
wall=220;requests[2].done(true,0);wall=230;ambience:Prepare('queue')
check(r.downloadCompleteWall==220 and r.queuedObservedWall==230,'ambience download/queue clocks')
wall=240;ambience:Prepare('ready')
check(r.readyObservedWall==240 and r.sourceObservedWall==240 and not r.pending,'ambience readiness')
wall=250;ambience.pending={id='amb_crater'}
ambience.gate:Start({'Sounds/Ambience/amb_crater_a.wav'},function()end)
ObserveAudioPreparation(app);local aborted=audioPreparation.events[3]
check(not aborted.readyObservedWall,'old ambience sound cannot mark new request ready')
wall=260;ambience.gate:Cancel();ambience.pending=nil;ObserveAudioPreparation(app)
check(aborted.cancelWall==260 and aborted.id=='amb_crater' and not aborted.readyObservedWall,'cancellation retains identity without stale ready')
wall=270;requests[3].done(true,0)
check(not aborted.downloadCompleteWall,'actual cancelled gate suppresses late callback')
for i=1,70 do wall=300+i;slot.gate:Start({'bounded/'..i},function()end)end
check(#audioPreparation.events==64 and audioPreparation.serial==73,'bounded history retains total request count')
check(audioPreparation.events[64].paths[1]=='bounded/70','bounded history retains latest actual path')
check(slot.gate.state=='loading' and slot.gate.total==1,'observer retains production gate state')
check(#cancelled==70,'actual gate cancellation count retained')
check(AudioPreparationState(nil).music.pending==false,'absent app snapshot safe')
return checks
''')
paths=['tools/migration/check-intro-qa-tools.py','tools/migration/check-intro-audio-meter.cjs',
       'tools/migration/check-intro-natural-web.cjs','tools/migration/probe-outgame-web.lua',
       'tools/migration/trace-resource-downloads.cjs','tools/migration/summarize-intro-downloads.cjs',
       'tools/migration/audit-unified-snapshot.cjs']
report={'result':'PASS','checks':meter['checks']+len(syntax)+release_checks+audio_checks,'audioMeter':meter,'syntax':syntax,
        'assetReleaseSnapshot':{'checks':release_checks,'result':'PASS','execution':'Exact current AssetReleaseState helper in Lua 5.4 with explicit fake app/cache/coordinator; lazy require forbidden'},
        'audioPreparationObserver':{'checks':audio_checks,'result':'PASS','productionGateSha256':hashlib.sha256((ROOT/'scripts/app/ResourceGate.lua').read_bytes()).hexdigest(),
            'execution':'Exact current observer and instance wrappers execute with actual ResourceGate and explicit backend/clock/audio-state adapters; request/callback timestamps, queue/ready upper bounds, cancellation, stale-source rejection, original return values and bounded history verified'},
        'inputs':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        'boundary':'Actual current AudioMeter callback extraction executes in a Node VM with an AudioContext adapter; current natural Web test and unified auditor pass Node syntax; full probe compiles with Lua 5.4. Exact AssetReleaseState and audio-preparation observer helpers execute against explicit doubles; audio observer also executes actual production ResourceGate. queued/ready/source times are observer upper bounds, not native EndLoad timings. These are evidence-tool hashes, not packaged production payloads. No browser, GPU, Web callback delivery, audible output, rendered appearance, native engine/API runtime or continuity acceptance.'}
out=ROOT/'docs/migration/evidence/intro-qa-tools-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','checks':report['checks'],'report':str(out)},ensure_ascii=False))
