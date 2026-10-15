-- October 14 opening clock. Host borrows the actual hall/battle, never screenshots.
local UI=require 'urhox-libs/UI'
local Coord=require 'core.Coord'
local M={};M.__index=M
local function Plain(text) return ((text or ''):gsub('<[^>]+>','')) end
function M.Data() return require('core.ResourceData').Read('Intro/Intro.json') end
function M.Dependencies()
 local data=M.Data();local result={'Intro/Intro.json','Intro/Fonts/TitleGlyphs.json','UI/IntroComicInkDots.png','UI/IntroComicPaperDots.png'}
 for _,path in ipairs(require('ui.IntroTypography').Dependencies()) do result[#result+1]=path end
 for _,path in pairs(data.audio) do result[#result+1]=path end
 for _,path in pairs(data.images) do result[#result+1]=path end
 return result
end
function M.New(app,host)
 local self=setmetatable({},M);self:init(app,host);return self
end
function M:init(app,host)
 self.app=app;self.host=assert(host,'Intro requires actual scene host');self.data=M.Data()
 self.active=false;self.stage='idle';self.shot='';self.time=0;self.age=0;self.log={};self.ink=0;self.strokes={};self.name='';self.holding=false
 self.audio=require('audio.IntroAudio').New(self.data);self.gate=require('app.ResourceGate').New()
 self.page=require('ui.IntroPage').New(self);self.part='';self.ready=false;self.failed=false;self.skipRequested=false
end
function M:Start(part)
 if self.active then return false end
 self.part=part or '';self.active=true;self.stage='boot';self.shot='boot';self.time=0;self.age=0
 self.previousFocus=UI.GetFocus();UI.ClearFocus();input.mouseMode=MM_ABSOLUTE
 if self.host.Begin then self.host.Begin(self) end
 UI.SetRoot(self.page);UI.PushOverlay(self.page)
 self.gate:Start(M.Dependencies(),function(ok,err)
  if not self.active then return end
  if not ok then self.failed=true;self.error=err;return end
  self.downloaded=true
 end)
 self.thread=coroutine.create(function() self:Run() end);return true
end
function M:ReadyScene()
 if self.scenePreparing or self.sceneReady then return end
 self.scenePreparing=true
 if not self.host.Prepare then
  self.failed=true;self.error='开篇实时场景尚未接入';return
 end
 self.host.Prepare(self,function() if self.active then self.sceneReady=true end end,function(err)
  if self.active then self.failed=true;self.error=tostring(err or '开篇场景加载失败') end
 end)
end
function M:Wait(duration)
 local untilAt=self.time+duration
 while self.active and self.time<untilAt do
  if self.stage=='ad' and self.skipRequested then return false end
  coroutine.yield()
 end
 return self.active and not (self.stage=='ad' and self.skipRequested)
end
function M:Mark(id,scene)
 self.shot=id;self.age=0;self.caption='';self.big='';self.face='smile';self.line=nil;self.wordAt=nil
 self.log[#self.log+1]={t=self.time,shot=id};print('[Intro] '..id)
 if scene and self.host.UseScene then self.host.UseScene(scene,self) end
 if self.host.Shot then self.host.Shot(id,self) end
end
function M:Say(id,tail,minimum,text)
 self.caption=text~=nil and text or self.data.caps[id] or ''
 local duration=self.audio:Voice('vo_'..id);duration=duration>0 and duration or self.data.durations['vo_'..id] or 2
 self.voiceDuration=duration;self.log[#self.log+1]={t=self.time,vo=id,dur=duration}
 return self:Wait(math.max(minimum or 0,duration+(tail or .15)))
end
function M:Vivi(id,face,wait)
 self.line=id;self.face=face or 'talk';self.lineAge=0;self.finishedTyping=false;self.advance=false;self.typedCount=-1
 self.voiceDuration=self.audio:Voice('vo_'..id)
 if self.voiceDuration<=0 then self.voiceDuration=self.data.durations['vo_'..id] or utf8.len(Plain(self.data.lines[id]))/9 end
 self.typing=math.max(.6,self.voiceDuration*.92)
 self.log[#self.log+1]={t=self.time,vo=id,dur=self.voiceDuration}
 while self.active and self.lineAge<self.voiceDuration do
  if self.advance then self.audio:StopVoice();break end
  coroutine.yield()
 end
 self.finishedTyping=true;self.advance=false
 if wait~=false then
  local at=self.time
  while self.active and self.time-at<.9 and not self.advance do coroutine.yield() end
 end
 self.advance=false
end
function M:Ad()
 self.stage='ad';self:Mark('logo');self.audio:Music('bgm_anthem_a',{vol=.95,fade=.3})
 if not self:Wait(2.9) then return end
 self:Mark('idyll','garage');if not self:Wait(.6) or not self:Say('n01',.3) then return end
 for _,step in ipairs({{'prosper','繁荣！','n02a',1.4,.45},{'order','秩序！','n02b',1.3,.45},{'leave','带薪年假……*','n02c',0,.1}}) do
  self:Mark(step[1]);self.big=step[2];self.audio:Sfx('slam',{vol=.75})
  if not self:Say(step[3],step[5],step[4],'') then return end
 end
 self:Mark('no');self.audio:StopMusic(.06);self.audio:Sfx('laser_charge',{vol=.9});if not self:Wait(.32) then return end
 self.audio:Sfx('laser_big');if not self:Wait(.08) then return end;self.audio:Sfx('pigeon');if not self:Wait(.1) then return end
 self.big='NO!';for _,id in ipairs({'laser_boom','holo_shatter','scratch'}) do self.audio:Sfx(id) end
 if not self:Wait(.7) then return end
 self:Mark('sortie-brief','crater');self.audio:Music('bgm_metal_a',{vol=.85,fade=.3})
 if not self:Wait(2.2) then return end
 self.advance=false;while self.active and not self.advance and not self.skipRequested do coroutine.yield() end
 if self.skipRequested then return end
 self:Mark('sortie-countdown');self.countdown='3';if not self:Wait(.5) then return end
 self.countdown='2';self.audio:Sfx('blip');if not self:Wait(.5) then return end
 self.countdown='1';self.audio:Sfx('blip');if not self:Wait(.5) then return end
 self.countdown='出动！';self:Mark('sortie-play')
 self.playing=true;self.sortie=require('intro.IntroSortie').New(self)
 assert(self.host.StartSortie,'Intro real driving host missing');self.host.StartSortie(self)
 while self.active and not self.sortie.done and not self.skipRequested do coroutine.yield() end
 self.playing=false;if self.host.EndSortie then self.host.EndSortie(self) end
 if self.skipRequested then return end
 self:Mark('familiar');if not self:Wait(1.23) or not self:Say('n03',.3,1.9) then return end
 self:Mark('galaxy');if not self:Say('n04',.35) then return end
 self:Mark('payslip','crater');if not self:Say('n05',.45) then return end
 self:Mark('decide');self.audio:StopMusic(.6);self.heart=self.audio:Sfx('heartbeat',{vol=.5,loop=true});self.holdProgress=0;self.holdIdle=0
 local voice=self.audio:Voice('vo_n06');self.caption=self.data.caps.n06
 if not self:Wait(1.2) then return end
 self.deciding=true;while self.active and self.holdProgress<1 and not self.skipRequested do coroutine.yield() end
 self.deciding=false;if self.skipRequested then return end
 if self.heart then self.heart:StopImmediate() end
 self:Mark('decided');self.audio:Sfx('spotlight');self.audio:Music('bgm_anthem_a',{vol=1,fade=.15,offset=38})
 if not self:Say('n07',.2) then return end
 for _,step in ipairs({{'m-build','n08','garage',0,.25},{'m-drive','n09','crater',0,.25},{'m-missile','n10','crater',4.6,.2},{'m-salvage','n11','crater',0,.2}}) do
  self:Mark(step[1],step[3]);self.audio:Sfx('whoosh',{vol=.5})
  if not self:Say(step[2],step[5],step[4]) then return end
 end
 for _,step in ipairs({{'recruit','加入星际前途','n12'},{'peacekeeper','维和先锋','n13'},{'master','零件大师','n14'},{'mechanic','战地机修师！','n15'},{'motto','','n16'},{'disclaimer','','n17'}}) do
  self:Mark(step[1]);self.big=step[2]
  if step[3]=='n14' then
   self.caption=self.data.caps.n14;local duration=self.audio:Voice('vo_n14');self.voiceDuration=duration
   if not self:Wait(duration*.42) then return end;self.big='英雄';self.wordAt=self.age
   if not self:Wait(duration*.34) then return end;self.big='成为——';self.wordAt=self.age
   if not self:Wait(duration*.24+.05) then return end
  elseif not self:Say(step[3],step[3]=='n15' and .35 or .15,nil,(step[1]=='motto' or step[3]=='n15') and '' or nil) then return end
 end
end
function M:Run()
 while self.active and (not self.ready or not self.clicked) do coroutine.yield() end
 self.audio:Sfx('crt_on',{vol=.8});self:Mark('crt');self:Wait(.65)
 if self.part~='contract' and self.part~='gate' then self:Ad() end
 self.stage='reality';self.playing=false;self.audio:StopVoice();self.audio:StopMusic(.1)
 if self.heart then self.heart:StopImmediate() end
 if self.part~='gate' then
  self:Mark('tvcut','garage');self.audio:Sfx('tv_cut',{vol=.5,stopAfter=.45});self:Wait(.46)
  self:Mark('comms','garage');self.alarm=self.audio:Sfx('alarm',{vol=.3,loop=true});self:Wait(.5)
  if self.part~='contract' then
   if self.skipRequested then self:Vivi('v13','deadpan') end
   for _,line in ipairs({{'v01','smile'},{'v02','talk'},{'v03','talk'},{'v04','deadpan'}}) do self:Vivi(line[1],line[2]) end
   self.choice=nil;self.chooseAge=0;self.choosing=true
   while self.active and not self.choice do if self.chooseAge>=14 then self:Choose(3) end;coroutine.yield() end
   self:Wait(.26);self.choosing=false;self:Vivi(({'v05','v06','v07'})[self.choice],({'smile','deadpan','smile'})[self.choice])
   self.choice=nil;self:Vivi('v08','talk');self:Vivi('v09','smile',false)
  end
  self:Mark('contract');self.audio:Music('bgm_jazz_a',{vol=.75,fade=1.2})
  if self.alarm then self.alarm:StopImmediate() end
  self.page:ShowContract(true)
  while self.active and not self.signed do coroutine.yield() end
  self.page:ShowContract(false);self.face='stamp';self:Wait(.3)
  self:Mark('stamp');self.face='stamp';self.audio:Sfx('stamp');self:Wait(.8)
  self:Vivi('v12','smile',false);self:Wait(.4)
 end
 self:Mark('gate','garage');self.audio:Sfx('slam',{vol=.55,rate=.8});self:Wait(.46)
 self.audio:Sfx('clang',{vol=.35,rate=.7});self:Wait(.35)
 for i=1,6 do self:Wait(.18);self.audio:Sfx('blip',{vol=.2,rate=1+i*.08}) end
 self.audio:Sfx('confirm',{vol=.5,rate=1.15});self:Wait(.55)
 for i=1,6 do self.audio:Sfx('clang',{vol=.16,rate=1.1+i*.05});self:Wait(.08) end
 self:Wait(.36);self.audio:Sfx('stamp',{vol=.4,rate=.7});self:Wait(.3)
 self.audio:Sfx('door_open',{vol=.75});self:Wait(.36);self:Wait(.3)
 self.gateCameraAt=self.time;self.audio:StopMusic(2);self:Wait(1.7);self:Wait(.5)
 self:Finish()
end
function M:Update(dt,focused)
 if not self.active then return end
 self.audio:Update(dt,focused)
 if self.host.Update then self.host.Update(focused==false and 0 or dt,self) end
 if focused==false then self.holding=false;return end
 dt=math.max(0,dt);self.time=self.time+dt;self.age=self.age+dt
 if self.pendingSignatureAt and self.time>=self.pendingSignatureAt then
  local name=self.pendingSignatureName;self.pendingSignatureAt=nil;self.pendingSignatureName=nil;self:PersistSignature(name)
 end
 if self.stage=='boot' and self.downloaded and not self.audioReady and not self.failed then
  local done,err=self.audio:PrepareNext();if err then self.failed=true;self.error=err elseif done then self.audioReady=true;self:ReadyScene() end
 end
 self.ready=self.audioReady and self.sceneReady and self.page.imageWarmup.ready and not self.failed
 if self.line then
  self.lineAge=self.lineAge+dt
  local count=utf8.len(Plain(self.data.lines[self.line])) or 0
  local shown=self.finishedTyping and count or math.min(count,math.floor(self.lineAge/math.max(.6,self.typing or 1)*count))
  if shown~=self.typedCount then self.typedCount=shown;if shown%3==0 then self.audio:Sfx('blip',{vol=.12,rate=1.4}) end end
 end
 if self.chooseAge then self.chooseAge=self.chooseAge+dt end
 if self.deciding then
  self.holdIdle=self.holding and 0 or self.holdIdle+dt
  self.holdProgress=math.max(0,math.min(1,self.holdProgress+(self.holding and dt/1.3 or self.holdIdle>5 and dt*.6 or -dt*.6)))
 end
 if self.playing and self.sortie then self.sortie:Update(dt) end
 if self.host.UpdateShot then self.host.UpdateShot(self.shot,dt,self.age,self) end
 if not self.failed and self.thread and coroutine.status(self.thread)~='dead' then
  local ok,err=coroutine.resume(self.thread)
  if not ok then self.failed=true;self.error=tostring(err);print('[Intro] ERROR '..self.error) end
 end
end
function M:Advance()
 if self.stage=='boot' then self.clicked=true;return end
 if self.shot=='sortie-brief' and self.age>=2.2 and self.host.CaptureSortie then self.host.CaptureSortie(self) end
 if self.line and not self.finishedTyping and self.lineAge<self.typing then self.finishedTyping=true
 else self.advance=true end
end
function M:Choose(index)
 if self.shot~='comms' or not self.choosing or self.choice or index<1 or index>3 then return false end
 self.choice=index;self.audio:Sfx('confirm',{vol=.6});return true
end
function M:Skip()
 if self.stage~='ad' then return false end
 self.skipRequested=true;self.audio:StopVoice();return true
end
function M:PersistSignature(name)
 self.name=name
 if self.host.SaveProfile then local ok,err=self.host.SaveProfile(name,os.time()*1000,self);if ok==false then self.error=tostring(err or '代号保存失败');return false end end
 self.signed=true;return true
end
function M:Submit(name)
 if self.shot~='contract' or self.signed or self.pendingSignatureAt then return false end
 name=(name or ''):match('^%s*(.-)%s*$');self.error=''
 if name=='' then self.error='代号不能为空。';self.face='deadpan';self.audio:Voice('vo_v10')
 elseif (utf8.len(name) or 99)>10 then self.error='代号最多 10 个字。';self.face='deadpan';self.audio:Voice('vo_v11')
 elseif name:sub(1,#'诺诺')=='诺诺' or name:lower()=='nono' then self.error='「别想冒充我。」——诺诺';self.face='deadpan'
 elseif self.ink<30 then self.error='请先在签名框里签一笔。';self.audio:Sfx('blip',{vol=.4})
 else
  if self.ink>800 then
   self.error='签得很认真。没用的。';self.pendingSignatureName=name;self.pendingSignatureAt=self.time+1.2;return true
  end
  return self:PersistSignature(name)
 end
 return false
end
function M:KeyDown(key,isRepeat)
 if not self.active then return false end
 if self.playing then return key==KEY_T or key==KEY_BACKSPACE end
 if self.shot=='contract' and UI.GetFocus()==self.page.nameField then return false end
 if key==KEY_SPACE then self.holding=true end
 if not isRepeat and (key==KEY_SPACE or key==KEY_RETURN) then self:Advance() end
 if key==KEY_1 then self:Choose(1) elseif key==KEY_2 then self:Choose(2) elseif key==KEY_3 then self:Choose(3) elseif key==KEY_ESCAPE then self:Skip() end
 return true
end
function M:KeyUp(key) if key==KEY_SPACE then self.holding=false end;return self.active and not self.playing end
local function Mix(a,b,t) return Coord.Vec(a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t) end
function M:Camera()
 if not self.active then return end
 if self.playing then if self.host.CameraShot then self.host.CameraShot(self.shot,self.age,self,self.host.GetCamera(self)) end;return end
 local camera=self.host.GetCamera and self.host.GetCamera(self);if not camera then return end
 local node=camera.node;local id=self.shot;local t=self.age
 if id=='idyll' then
  local k=math.min(1,t/6);k=k<.5 and 4*k^3 or 1-(-2*k+2)^3/2
  node.position=Mix({7,1,-28},{2,5,-40},k);node:LookAt(Mix({2,4,-90},{-4,16,-90},k));camera.fov=52-6*k
 elseif id=='comms' or id=='contract' or id=='stamp' then
  node.position=Coord.Vec(-13+math.sin(t*.07)*2,4.2,15-t*.05);node:LookAt(Coord.Vec(2,1.6,0));camera.fov=46
 elseif id=='gate' and self.gateCameraAt then
  local k=math.min(1,(self.time-self.gateCameraAt)/2.4);k=k<.5 and 4*k^3 or 1-(-2*k+2)^3/2
  node.position=Mix({0,6,-34},{6.5,4.2,10.5},k);node:LookAt(Mix({0,3,0},{0,1.2,0},k));camera.fov=58-10*k
 elseif id=='m-build' then
  local a=.6+t*.4;local r=27-t*1.6;node.position=Coord.Vec(math.sin(a)*r,8-t*.8,math.cos(a)*r);node:LookAt(Coord.Vec(0,3,0));camera.fov=44
 end
 if self.host.CameraShot then self.host.CameraShot(id,t,self,camera) end
end
function M:Finish()
 if not self.active then return end;self.log[#self.log+1]={t=self.time,shot='end'}
 self:Dispose();if self.host.Finish then self.host.Finish(self,self.name) end
end
function M:Dispose()
 if self.disposed then return end;self.disposed=true;self.active=false;self.playing=false;self.thread=nil
 self.gate:Cancel();self.audio:Dispose();self.page:Close();input.mouseMode=MM_ABSOLUTE
 if self.host.Dispose then self.host.Dispose(self) end
end
return M
