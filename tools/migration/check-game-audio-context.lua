package.path='scripts/?.lua;'..package.path
local checks=0
local function Check(ok,message) checks=checks+1;assert(ok,message) end
local function Near(a,b,message) Check(math.abs(a-b)<1e-10,message..': '..tostring(a)..' / '..tostring(b)) end
local clock=0;Time={GetSystemTime=function() return clock*1000 end}
package.preload['core.ResourceData']=function() return {Read=function(path) return assert(CONFIGS[path],path) end} end
local Levels=require 'audio.AudioLevels'
local State=require 'audio.GameMusicState'
local owner={}
for _,case in ipairs(SOURCE.cases) do
 Levels.Init(nil);Levels.SetSpeaking(owner,case.voice);if case.feedback then Levels.FeedbackFor(10) end
 local actual=State.Resolve(case.drive,{screen='home'},case.intro,false,false)
 for _,key in ipairs({'scene','destination','matching','paused','duck'}) do Check(actual[key]==case.expected[key],case.name..' '..key) end
end
Levels.SetSpeaking(owner,false);Levels.Init(nil)
local function Source()
 return {soundType='VoxWeapons',gain=0,playing=false,frequency=48000,panning=0,
  SetSoundType=function(self,kind) self.soundType=kind end,
  Play=function(self,sound,frequency,gain,pan) self.playing=true;self.gain=gain;self.frequency=frequency;self.panning=pan or 0;self.sound=sound end,
  StopImmediate=function(self) self.playing=false end,Dispose=function() end}
end
local root={CreateComponent=function() return Source() end,Dispose=function() end}
function root:CreateChild() return self end
Scene=function() return root end
input={focus=true,minimized=false};audio={PauseSoundType=function() end,ResumeSoundType=function() end}
cache={Exists=function() return true end,GetResource=function(_,_,path) return {length=.5,GetFrequency=function() return 48000 end} end}
cache.GetExistingResource=cache.GetResource
local buses={}
for _,id in ipairs({'driving','weapons','damage','ambience','feedback','ui'}) do
 local sound=Source();Levels.Play(sound,{},0,.65,0,'sfx',id);buses[id]=sound
end
for _,sample in ipairs(SOURCE.mix) do
 if sample.feedback then Levels.FeedbackFor(10) else clock=clock+11 end
 Levels.MixContext(sample.dt,sample.briefing)
 for id,expected in pairs(sample.buses) do Near(buses[id].gain,.65*.65/.6*expected,'frozen JS context bus '..id) end
 Check(Levels.ContextSnapshot().target==(sample.briefing and .3 or sample.feedback and .65 or 1),'read-only context target')
end
for _,sample in ipairs(SOURCE.masters) do
 Levels.Set('sfx',sample.volume);Near(Levels.ContextSnapshot().sampleMaster,sample.gain,'frozen JS sample master')
end
-- Source categories share the original sample master; IntroAudio does not.
Levels.Init(nil);Levels.MixContext(30,true)
local original=Source();Levels.Play(original,{},0,.65,0,'sfx')
Near(original.gain,.65,'separate intro graph is not rescaled or ducked')
local Weapon=require 'audio.WeaponAudio';local weapons=Weapon.New(root);weapons.active=true
local Driving=require 'audio.DrivingAudio';local driving=Driving.New(root);driving.active=true
local Feedback=require 'audio.CombatFeedbackAudio';local feedback=Feedback.New(root);feedback.active=true
local counts={weapons=0,driving=0,feedback=0,flow=0,radio=0}
-- Avoid random pool lookup ambiguity while preserving production random calls.
local damage={vehicle_collision=true,vehicle_destroy=true,part_break=true,part_detach=true,shield_up=true,shield_hit=true,shield_down=true}
local function Cues(module,config,category,busFor)
 for id,cue in pairs(CONFIGS[config].cues) do if not cue.loop then
  clock=clock+10;module.time=module.time+10;Check(module:Play(id,.7,.2),'actual cue starts '..id)
  local expected=SOURCE.cues[id];Near(cue.gain,expected.gain,'source trim '..id);Near(cue.gap,expected.gap/1000,'source gap '..id)
  if not id:find('__',1,true) then Check(Levels.FeedbackActive()==expected.feedback,'source feedback window '..id) end
  local bus=busFor(id);Check(bus==expected.bus,'source bus '..id)
  local played;for _,slot in ipairs(module.slots or module.voices) do local s=slot.source or slot;if s.playing then played=s end end
  Near(played.gain,expected.gain*.7*.65*.65/.6*((bus=='weapons' or bus=='driving' or bus=='damage') and .3 or 1),'actual mixer gain '..id)
  counts[category]=counts[category]+1
  for _,slot in ipairs(module.slots or module.voices) do (slot.source or slot):StopImmediate() end
 end end
end
Cues(weapons,'Combat/WeaponSounds.json','weapons',function(id) return id=='energy_online' and 'feedback' or 'weapons' end)
Cues(driving,'Combat/DrivingSounds.json','driving',function() return 'driving' end)
Cues(feedback,'Combat/FeedbackSounds.json','feedback',function(id) return damage[id] and 'damage' or 'feedback' end)
clock=clock+10
for id,cue in pairs(CONFIGS['Combat/WeaponSounds.json'].cues) do if cue.loop then
 weapons:Loop(id,.8,1,0,30)
 Near(weapons.loops[id].source.gain,SOURCE.cues[id].gain*.8*.65*.65/.6*.3,'actual weapon loop context '..id)
 Levels.MixContext(30,false);weapons:Loop(id,.8,1,0,30)
 Near(weapons.loops[id].source.gain,SOURCE.cues[id].gain*.8*.65*.65/.6,'actual weapon loop context release '..id)
 Levels.MixContext(30,true)
end end
for id,cue in pairs(CONFIGS['Combat/DrivingSounds.json'].cues) do if cue.loop then
 driving:Loop(id,id,.8,1,0,30)
 Near(driving.loops[id].source.gain,SOURCE.cues[id].gain*.8*.65*.65/.6*.3,'actual driving loop context '..id)
 Levels.MixContext(30,false);driving:Loop(id,id,.8,1,0,30)
 Near(driving.loops[id].source.gain,SOURCE.cues[id].gain*.8*.65*.65/.6,'actual driving loop context release '..id)
 Levels.MixContext(30,true)
end end
local Flow=require 'audio.BattleFlow';local flow=Flow.New();flow:Prepare(true)
for id,cue in pairs(CONFIGS['Combat/FlowSounds.json'].cues) do if not cue.loop then
 flow.time=flow.time+10;Check(flow:Play(id),'flow cue starts '..id)
 local expected=SOURCE.cues[id];Near(cue.gain,expected.gain*.65,'prebaked source flow trim '..id)
 Near(flow.slots[flow.cursor].gain,expected.gain*.65*.65/.6,'flow gain '..id)
 Check(Levels.FeedbackActive()==expected.feedback,'flow feedback window '..id);counts.flow=counts.flow+1
end end
local Radio=require 'audio.StoryRadio';local radio=Radio.New()
for name,cue in pairs(CONFIGS['Story/Radio/Radio.json'].cues) do
 clock=clock+10;radio.time=radio.time+10;Check(radio:Play(name),'radio starts '..name)
 local expected=SOURCE.cues[cue.id];Near(cue.gain,expected.gain,'source radio trim '..name)
 local playing;for _,slot in ipairs(radio.slots) do if slot.source.playing then playing=slot.source end end
 Near(playing.gain,expected.gain*cue.strength*.65*.65/.6*(cue.bus=='weapons' and .3 or 1),'radio gain '..name)
 Check(Levels.FeedbackActive()==expected.feedback,'radio feedback window '..name)
 for _,slot in ipairs(radio.slots) do slot.source:StopImmediate() end;counts.radio=counts.radio+1
end
local home=State.FromApp({mode='hangar',lobby='salvage'},{tab='hangar'});Check(home.scene=='hangar','warehouse lobby retains source hangar theme')
for _,map in ipairs({'trial','crater','story1','story5','endless','salvage'}) do
 local app={mode='trial',trial={map={id=map,storyLevel=map=='story5' and 5 or map=='story1' and 1 or nil},pointer={captured=true}}}
 local expected=map=='trial' and 'training' or map=='salvage' and 'salvage' or 'drive-combat'
 Check(State.FromApp(app,{}).scene==expected,'actual app mapping '..map)
 app.trial.intro={done=false};Check(State.FromApp(app,{}).duck==.25,'actual briefing mapping '..map)
end
-- Real player context never overwrites the separately persisted user pause.
local Player=require 'audio.MusicPlayer';Levels.Init(nil)
local player=Player.New(nil,cache)
player:Update(.12,'drive-combat',false,{duck=.63,paused=true})
Check(player.contextPaused and not player.userPaused and not player:CanPlay(),'opening context pauses independent player bus')
Near(player.duckLevel,1+(.63-1)*(1-math.exp(-1)),'firing music attack .12')
player:SetPaused(true);local previous=player.duckLevel
player:Update(1.2,'drive-combat',false,{duck=1,paused=false})
Check(not player.contextPaused and player.userPaused and not player:CanPlay(),'leaving context preserves explicit user pause')
Near(player.duckLevel,previous+(1-previous)*(1-math.exp(-1)),'music release 1.2')
player:SetLibraryMode(true);player:Update(.12,'drive-combat',false,{duck=.25,paused=true})
Check(not player.contextPaused and player.duck==1 and player.group=='music-box','library context overrides scene pause and duck')
player:SetLibraryMode(false);player:Update(.1,'salvage',true,{duck=.5,paused=false})
Check(player.hidden and not player:CanPlay(),'library exit preserves native hidden pause')
player:Dispose()
return {status='PASS',checks=checks,cases=#SOURCE.cases,cueCounts=counts,
 boundary='Real frozen JS state/cue registry/uiSound mixContext and real Lua audio modules executed with sound/input/scene/cache adapters. Does not prove native gain headroom, DSP parity, audible output, callback continuity, Web performance, GPU or mobile.'}
