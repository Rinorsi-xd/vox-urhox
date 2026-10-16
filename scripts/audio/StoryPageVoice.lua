-- Selection-page audio owns its sources; it cannot steal the tutorial card.
local ResourceGate=require("app.ResourceGate")

local Levels=require 'audio.AudioLevels'
local M={};M.__index=M
function M.New()
    local self=setmetatable({loaded={},gates={},downloaded={},decoding={},decodeCursor=1,slots={},time=0,active=0,log={}},M)
    self.scene=Scene();local root=self.scene:CreateChild('StoryPageVoice')
    for i=1,2 do local source=root:CreateComponent('SoundSource');source:SetSoundType('VoxStoryVoice');self.slots[i]={source=source} end
    return self
end
function M:Load(id)
    if self.loaded[id]~=nil then return end
    local path='Story/Page/'..id..'.mp3'
    local existing=cache:GetExistingResource('Sound',path)
    if existing and existing.length>0 then self.loaded[id]=existing;return end
    self.loaded[id]=false
    local function Ready(sound) if not self.disposed and sound and sound.length>0 then self.loaded[id]=sound end end
    if cache.GetResourceAsync then cache:GetResourceAsync('Sound',path,Ready)
    else local gate=ResourceGate.New();self.gates[#self.gates+1]=gate
        gate:Start({path},function(ok)
            if ok and not self.disposed then self.downloaded[#self.downloaded+1]={id=id,path=path} end
        end)
    end
end
function M:Fade()
    for _,slot in ipairs(self.slots) do if slot.source.playing then slot.fade=.35;slot.gain=Levels.RawGain(slot.source) end end
    self.card=nil;Levels.SetSpeaking(self,false)
end
function M:Select(level,text,voice)
    self:Fade();local count=utf8.len(text) or #text
    self.card={text=text,count=count,shown=0,age=0,wait=0,step=voice and .034 or .028,phase='nono',talking=true,
        nono=string.format('C-%02d',level*2-1),huhu=string.format('C-%02d',level*2),pending=voice==true}
    if voice then self:Load(self.card.nono);self:Load(self.card.huhu) end
end
function M:Play(level,text) self:Select(level,text,true) end
function M:StartLine(card,id)
    local sound=self.loaded[id];if not sound then return false end
    self.active=self.active%2+1;local slot=self.slots[self.active]
    slot.source:StopImmediate();slot.fade=nil;card.sound=sound;card.age=0;card.started=false;card.pending=false
    card.duration=.26+sound.length+.26;card.step=math.min(.034,sound.length*.85/math.max(1,card.count))
    self.log[#self.log+1]=id;return true
end
function M:Update(dt,focus)
    if self.disposed then return end
    -- Completion can run in the download stack. Prepare on the page clock.
    local item=table.remove(self.downloaded,1)
    if item then
        local sound=cache:GetExistingResource('Sound',item.path)
        if sound and sound.length>0 then self.loaded[item.id]=sound
        else
            cache:BackgroundLoadResource('Sound',item.path,true)
            self.decoding[#self.decoding+1]=item
        end
    end
    local queue=self.decoding
    for _=1,math.min(4,#queue) do
        if #queue==0 then break end
        local index=self.decodeCursor;local pending=queue[index]
        local sound=cache:GetExistingResource('Sound',pending.path)
        if sound and sound.length>0 then
            self.loaded[pending.id]=sound;queue[index]=queue[#queue];table.remove(queue)
        else self.decodeCursor=index+1 end
        if self.decodeCursor>#queue then self.decodeCursor=1 end
    end
    for _,slot in ipairs(self.slots) do if slot.fade then
        slot.fade=math.max(0,slot.fade-dt);Levels.SetGain(slot.source,slot.gain*slot.fade/.35)
        if slot.fade==0 then slot.source:StopImmediate();slot.fade=nil end
    end end
    local card=self.card;if not card or focus==false then return end
    if card.pending then
        card.wait=card.wait+dt
        if self:StartLine(card,card.nono) then card.wait=0
        elseif card.wait<1.5 then return
        else card.pending=false;card.step=.034 end
    end
    card.age=card.age+dt
    if card.sound and not card.started and card.age>=.26 then
        card.started=true;Levels.Play(self.slots[self.active].source,card.sound,0,.4)
    end
    if card.phase=='nono' then
        card.shown=math.min(card.count,math.floor(card.age/card.step))
        if card.sound then
            if card.age>=card.duration+.35 then
                card.talking=false;card.phase='huhu';card.sound=nil
                if self:StartLine(card,card.huhu) then card.intercept=true else card.phase='done' end
            end
        elseif card.shown>=card.count then card.talking=false;card.phase='done' end
    elseif card.phase=='huhu' and card.age>=(card.duration or 0)+.3 then card.intercept=false;card.phase='done';card.sound=nil end
    Levels.SetSpeaking(self,card.sound~=nil and card.age<(card.duration or 0))
end
function M:Text()
    local c=self.card;if not c then return '' end
    local stop=utf8.offset(c.text,c.shown+1);return stop and c.text:sub(1,stop-1) or c.text
end
function M:Dispose()
    if self.disposed then return end;self:Fade();self.disposed=true
    for _,gate in ipairs(self.gates) do gate:Cancel() end
    for _,slot in ipairs(self.slots) do slot.source:StopImmediate() end
    self.scene:Dispose();self.loaded={};self.downloaded={};self.decoding={}
end
return M
