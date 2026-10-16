-- Recruitment cards keep their source exit animation while the next card enters.
local Card=require 'ui.IntroTitleCard'
local Opacity=require 'ui.IntroOpacity'
local Ease=require('ui.IntroGateMotion').Ease
local M={}
local stages={recruit=true,peacekeeper=true,master=true,mechanic=true,motto=true,disclaimer=true}
local titles={recruit='加入星际前途',peacekeeper='维和先锋',master='零件大师',mechanic='战地机修师！'}
function M.Handles(id)return stages[id] end
function M.Draw(vg,I,w,h,u)
 if not stages[I.shot] then return end
 local events={};local now=I.time or I.age
 local function Add(id,text,at,duration)events[#events+1]={id=id,text=text,at=at,duration=duration}end
 for _,entry in ipairs(I.log or {}) do
  local id=entry.shot
  if titles[id] then
   Add(id,titles[id],entry.t,id=='master' and .12 or .2)
   if id=='master' then
    local duration=I.shot=='master' and I.voiceDuration or I.data.durations.vo_n14
    duration=duration or I.data.durations.vo_n14
    if I.shot~='master' or I.big=='英雄' or I.big=='成为——' then
     local at=I.shot=='master' and I.big=='英雄' and I.wordAt or duration*.42
     Add(id,'英雄',entry.t+at,.12)
    end
    if I.shot~='master' or I.big=='成为——' then
     Add(id,'成为——',entry.t+(I.shot=='master' and I.wordAt or duration*.76),.1)
    end
   end
  elseif id=='motto' then Add(id,nil,entry.t,0) end
 end
 if #events==0 and titles[I.shot] then Add(I.shot,I.big or titles[I.shot],now-I.age+(I.wordAt or 0),.2) end
 for index,event in ipairs(events) do
  local nextEvent=events[index+1];local exitAge=nextEvent and now-nextEvent.at
  if event.text and now>=event.at and (not exitAge or exitAge<event.duration-.000000001) then
   local progress=exitAge and Ease(exitAge/event.duration,.42,0,1,1) or 0
   local plan=Card.Plan(event.id,event.text)
   Opacity.Push(vg,1-progress)
   local cx,cy=w*.5,h*.44;local scale=1+.08*progress
   nvgTranslate(vg,cx,cy);nvgScale(vg,scale,scale);nvgTranslate(vg,-cx,-cy)
   Card.Draw(vg,w,h,u,now-event.at,plan)
   Opacity.Pop(vg)
  end
 end
end
return M
