-- The original guided live battle; elapsed action time pauses with pointer lock.
local M={};M.__index=M
function M.New(intro)
 local self=setmetatable({},M);self.intro=intro;self.step=0;self.elapsed=0;self.controlling=false;self.tip='';self.done=false;return self
end
function M:Next(step)
 self.step=step;self.elapsed=0;self.intro.audio:Sfx('blip',{vol=.5})
 -- 触屏没有 W / 左键：提示换成摇杆与开火键（源 introSortie.js 只写了键鼠）
 local touch=require('controls.TouchMode').Enabled()
 self.tip=({touch and '摇杆往前推 冲过去 · 车会朝准星的方向开' or '按住 W 冲过去 · 车会朝准星的方向开',
  touch and '按住开火键 · 打掉冲在最前面那辆！' or '左键 开火 · 打掉冲在最前面那辆！',
  '暴走战车群盯上你了 · 撑住！援军到达还有 10 秒','援军已到达！友军火控：锁定目标中……','战车已损毁'})[step]
 if self.intro.host.SortieStep then self.intro.host.SortieStep(step,self.intro) end
end
function M:Complete(step)
 self.pending=step;self.completeAge=0;self.tip='完成！';self.intro.audio:Sfx('confirm',{vol=.5})
end
function M:Update(dt)
 local I=self.intro;local status=I.host.SortieStatus and I.host.SortieStatus(I) or nil
 if not status then return end
 if self.pending then self.completeAge=self.completeAge+dt;if self.completeAge>=.5 then local step=self.pending;self.pending=nil;self:Next(step) end;return end
 self.controlling=status.controlling==true
 if self.step==0 then if self.controlling then self.origin={table.unpack(status.pos or {62,0,-176})};self:Next(1) end;return end
 if self.step<=3 and not self.controlling then return end
 self.elapsed=self.elapsed+dt
 if self.step==1 then
  local p=status.pos or self.origin;local dist=math.sqrt((p[1]-self.origin[1])^2+(p[3]-self.origin[3])^2)
  if dist>18 or self.elapsed>=9 then self:Complete(2) elseif self.elapsed>=4 then self.tip='按住键盘上的 W · 车就会往前开' end
 elseif self.step==2 then
  if status.enemyHit or self.elapsed>=15 then
   self.mine=status.enemyHit==true;self.killAt=I.time
   if I.host.SortieHit then I.host.SortieHit(self.mine,I) end
   I.audio:Sfx('slam',{vol=.9});self:Complete(3)
  elseif self.elapsed>=6 then self.tip='把准星对准红色「打它！」· 按住 左键' end
 elseif self.step==3 then
  self.left=math.max(0,10-self.elapsed);self.tip='暴走战车群盯上你了 · 撑住！援军到达还有 '..math.ceil(self.left)..' 秒'
  if I.host.SortieDamageScale then I.host.SortieDamageScale(.15+self.elapsed*.04,I) end
  if status.playerAlive==false then self.reason='被暴走战车群击毁';self:Next(5)
  elseif self.elapsed>=10 then self.reason='被「援军」误伤';self:Next(4) end
 elseif self.step==4 and self.elapsed>=2.05 then self:Next(5)
 elseif self.step==5 then
  if self.elapsed>=.9 and not self.stamped then
   self.stamped=true;I.audio:Sfx('stamp',{vol=.9})
   if I.host.CaptureWreck then I.host.CaptureWreck(I) end
  end
  if self.elapsed>=3.3 then self.done=true;I.wrecked=true end
 end
end
return M
