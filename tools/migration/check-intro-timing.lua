package.path='scripts/?.lua;'..package.path
local noop=function()end
package.loaded['urhox-libs/UI']={GetFocus=noop}
package.loaded['core.Coord']={}
package.loaded['core.ResourceData']={Read=function()return TIMING_DATA end}
package.loaded['app.ResourceGate']={New=function()return {}end}
package.loaded['ui.IntroPage']={New=function()return {imageWarmup={ready=true},ShowContract=noop}end}
package.loaded['intro.IntroSortie']={New=function()return {done=true}end}
print=noop
local Session=require 'intro.IntroSession'
return function(held,n06,n10,skipShot,part)
 local I;local shots={};local voices={};local firing={};local sounds={};local clock=0
 package.loaded['audio.IntroAudio']={New=function()return {Update=noop,Sfx=function(_,id,opt)sounds[#sounds+1]={t=clock,id=id,opt=opt,shot=I.shot};return {StopImmediate=noop}end,
  StopSfx=function(_,source,fade)sounds[#sounds+1]={t=clock,id='stopAlarm',fade=fade}end,
  StopMusic=function(_,fade)sounds[#sounds+1]={t=clock,id='stopMusic',fade=fade}end,
  Music=function(_,id,opt)sounds[#sounds+1]={t=clock,id=id,opt=opt}end,StopVoice=noop,Voice=function(_,id)
   voices[#voices+1]={t=clock,id=id,caption=I.caption};return id=='vo_n06' and n06 or id=='vo_n10' and n10 or TIMING_DATA.durations[id] or 2
  end}end}
 I=Session.New({},{StartSortie=noop,Shot=function(id,self)shots[#shots+1]={t=self.time,id=id}end})
 I.active=true;I.ready=true;I.audioReady=true;I.sceneReady=true;I.holding=held
 I.clicked=true;I.part=part or '';I.signed=true
 I.Vivi=noop;I.Finish=function(self)self.completed=true end
 I.thread=coroutine.create(function()if part then I:Run()else I:Ad()end end)
 local dt=1/240
 for frame=1,60000 do
  clock=I.time+dt
  if I.shot=='sortie-brief' and I.age>=2.2 then I.advance=true end
  if skipShot and I.shot==skipShot and I.age>.4 then I:Skip()end
  I:Update(dt,true)
  if I.shot=='m-missile' then firing[#firing+1]={age=I.age,on=I.missileFiring~=false}end
  assert(not I.failed,I.error)
  if coroutine.status(I.thread)=='dead' then return {shots=shots,voices=voices,firing=firing,sounds=sounds,skipped=I.skipRequested}end
 end
 error('Lua opening timing timeout')
end
