package.path='scripts/?.lua;?.lua;'..package.path
local checks=0
local function Check(v,msg) checks=checks+1;assert(v,msg) end
local soundData=TEST_SOUND_DATA
package.preload['core.ResourceData']=function() return {Read=function() return soundData end} end
local callback,offCount,scale,hit=nil,0,2,nil
local UI={Button={_className='Button'},GetScale=function() return scale end,FindWidgetAt=function(x,y) Check(x==20 and y==30,'physical pointer converted to same base hit-test coordinates');return hit end,
    Input={On=function(name,fn) Check(name=='PointerDown','one down listener, no hover');callback=fn;return 42 end,
        Off=function(name,id) Check(name=='PointerDown' and id==42,'exact input subscription removed');offCount=offCount+1 end}}
package.preload['urhox-libs/UI']=function() return UI end
local ms,background,existing=1000,{},{}
Time={GetSystemTime=function() return ms end}
input={focus=true,minimized=false}
cache={GetExistingResource=function(_,kind,path) Check(kind=='Sound','existing-only sound readiness query');return existing[path] end,
    BackgroundLoadResource=function(_,kind,path) Check(kind=='Sound','background preparation only');background[#background+1]=path;return true end,
    GetResource=function() error('input must not synchronously decode') end}
local roots={}
function Scene()
 local scene={disposed=false};roots[#roots+1]=scene
 function scene:CreateChild()
  local root={}
  function root:CreateComponent(kind)
   Check(kind=='SoundSource','bounded native playback component');local s={playing=false,stops=0,plays=0}
   function s:SetSoundType(bus) self.soundType=bus end
   function s:StopImmediate() self.playing=false;self.stops=self.stops+1 end
   function s:Play(sound,freq,gain,pan) self.playing=true;self.plays=self.plays+1;self.frequency=freq;self.gain=gain;self.pan=pan;self.sound=sound end
   return s
  end
  return root
 end
 function scene:Dispose() self.disposed=true end
 return scene
end
local cueCount=0;for _ in pairs(soundData.cues) do cueCount=cueCount+1 end
package.preload['app.ResourceGate']=function() return {New=function()return {state='ready',Start=function(_,paths,done) Check(#paths==cueCount,'only selected original cues downloaded');done(true) end,Cancel=function()end}end}end
local Levels=require 'audio.AudioLevels';local Sound=require 'audio.UiSound'
local s=Sound.Start();Check(#background==0 and #s.voices==10,'download callback only marks readiness and original ten fixed voices')
Check(not Sound.Play('press'),'not-yet-decoded sample skips without blocking input')
for i=1,cueCount do Sound.Update();Check(#background==i,'one preparation queued on each later update')end
for id,cue in pairs(soundData.cues) do existing[cue.path]={id=id} end
for _=1,math.ceil(cueCount/4)do Sound.Update()end
Check(Sound.Snapshot().ready==cueCount,'async existing-resource readiness recovers within bounded poll rounds')
local class=setmetatable({_super=UI.Button},{__index=UI.Button});class.__index=class
local button=setmetatable({props={disabled=false}},class)
for _,case in ipairs(TEST_SOURCE.pointer) do
 hit=case.exists and button or nil;button.props.disabled=case.disabled;ms=ms+1000
 local prior=s.counts.press or 0
 callback({x=40,y=60,IsPrimaryAction=function()return case.button==0 end})
 Check((s.counts.press or 0)-prior==#case.sounds,'exact frozen document button press condition')
end
button.props.disabled=false;hit={parent=button};ms=ms+1000;callback({x=40,y=60,IsPrimaryAction=function()return true end})
Check(s.counts.press==2,'button descendant uses closest button')
hit={UiSoundButtonAt=function(_,x,y)return x==20 and y==30 end};ms=ms+1000;callback({x=40,y=60,IsPrimaryAction=function()return true end})
Check(s.counts.press==3,'self-drawn tutorial button hit uses same tree')
Check(not Sound.Play('press'),'global pointerdown and tutorial click deduplicated within85ms')
ms=ms+84;Check(not Sound.Play('press'),'press before85ms suppressed');ms=ms+2;Check(Sound.Play('press'),'press after85ms allowed')
-- Construct actual engine property-routed instances, whose metatable is not the class.
local Widget={_className='Widget'}
function Widget:Init()end
function Widget:ApplyStyleToYoga()end
function Widget:ProcessChildren()end
local setup='local Widget=...;local SCROLL_UPGRADEABLE_={};local Style={NormalizeColorProps=function()end};'..
    'local function YGNodeNew()return {}end;local function buildSetterMap()return {}end;'..
    ENGINE_EXTEND..'\n'..ENGINE_WIDGET_NEW..'\nreturn Widget'
assert(load(setup))(Widget)
local NativeButton=Widget:Extend('Button');UI.Button=NativeButton
local NativeAction=NativeButton:Extend('VoxActionButton')
local NativeSource=NativeAction:Extend('VoxSourceButton')
for _,cls in ipairs({NativeButton,NativeAction,NativeSource})do for _,disabled in ipairs({false,true})do
 hit=cls:new({disabled=disabled});ms=ms+1000
 Check(getmetatable(hit)~=cls,'actual Widget:new property-routing metatable')
 local prior=s.counts.press or 0
 callback({x=40,y=60,IsPrimaryAction=function()return true end})
 Check((s.counts.press or 0)-prior==(disabled and 0 or 1),'actual native/routed descendant button recognized once')
end end
hit=Widget:new({});ms=ms+1000;local prior=s.counts.press
callback({x=40,y=60,IsPrimaryAction=function()return true end})
Check(s.counts.press==prior,'actual non-button does not sound')
local playedPress;for _,v in ipairs(s.voices) do if v.id=='press' then playedPress=v.source end end
Check(math.abs(playedPress.gain-.065*.65/.6)<1e-12,'source press gain times original shared sample master .65*.65/.6')
ms=ms+1000;Check(Sound.Play('confirm'),'actual confirm exists');Check(not Sound.Play('confirm'),'confirm100ms gap')
for i=1,30 do ms=ms+1000;Check(Sound.Play(i%2==0 and 'press' or 'confirm'),'bounded overlap '..i) end
local same={};for _,v in ipairs(s.voices) do if v.source.playing then same[v.id]=(same[v.id]or 0)+1 end end
Check(same.press==3 and same.confirm==3 and #s.voices==10,'same cue maximum3 and total fixed10')
for _,voice in ipairs(s.voices)do voice.source:StopImmediate()end
for id,cue in pairs(soundData.cues)do
 ms=ms+1000;Check(Sound.Play(id),'all approved cues playable: '..id)
 local played;for _,voice in ipairs(s.voices)do if voice.id==id and voice.source.playing then played=voice.source end end
 Check(played and math.abs(played.gain-cue.gain*.65*.65/.6)<1e-12,'each original cue gain: '..id)
 Check(not Sound.Play(id),'each original cue repeat gap: '..id)
 ms=ms+math.floor(cue.gap*1000)+1;Check(Sound.Play(id),'each original cue recovers after gap: '..id)
end
local active,perCue=0,{}
for _,voice in ipairs(s.voices)do if voice.source.playing then active=active+1;perCue[voice.id]=(perCue[voice.id]or 0)+1 end end
Check(active==10 and #s.voices==10,'seven cue overlap remains globally bounded to ten original voices')
for id,count in pairs(perCue)do Check(count<=3,'all cue overlap remains at most three: '..id)end
ms=ms+1000;Sound.Play('press');for _,voice in ipairs(s.voices)do if voice.id=='press' and voice.source.playing then playedPress=voice.source end end
Levels.Set('sfx',.325);Check(math.abs(playedPress.gain-.0325*.65/.6)<1e-12,'existing voices respond to shared sfx level')
Levels.Set('sfx',0);ms=ms+1000;Check(not Sound.Play('press'),'zero volume suppresses playback')
Levels.Set('sfx',.65);input.focus=false;Sound.Update();for _,v in ipairs(s.voices) do Check(not v.source.playing,'focus loss stops each voice')end
Check(not Sound.Play('press'),'unfocused does not play');input.focus=true;input.minimized=true;Check(not Sound.Play('press'),'minimized does not play');input.minimized=false
ms=ms+1000;Check(Sound.Play('press'),'focused UI playback resumes')
Check(not Sound.Play('hover') and not Sound.Play('invented'),'source hover remains silent and missing cues do not synthesize')
Sound.Dispose();Check(roots[1].disposed and offCount==1 and not Sound.Snapshot().active,'scene and subscription released')
Sound.Dispose();Check(offCount==1,'repeated Dispose idempotent');Check(not Sound.Play('press'),'disposed cues do not play')
Sound.Start();Sound.Start();Check(roots[2].disposed and offCount==2,'restart replaces old owner and listener');Sound.Dispose()
return checks
