-- shared/ui/nonoComms.js: one retained card, with ownership-safe client handles.
local Levels=require 'audio.AudioLevels'
local M={}
local shared=nil ---@type table|nil
local fields={card=true,queue=true,time=true,keepOpen=true}
local empty={}
local function Normalize(text)
    local out={};text=text:gsub('^【[^】]*】','')
    for _,code in utf8.codes(text) do
        if code>=0x3400 and code<=0x9fff or code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122 then out[#out+1]=utf8.char(code) end
    end
    return table.concat(out)
end
M.__index=function(self,key)
    if M[key] then return M[key] end
    if fields[key] then return shared and shared.owner==self and shared[key] or (key=='queue' and empty or nil) end
end
M.__newindex=function(self,key,value)
    if fields[key] then if shared and shared.owner==self then shared[key]=value end
    else rawset(self,key,value) end
end
local function Fade()
    if not shared then return end
    local slot=shared.slots[shared.active]
    if slot and slot.source.playing then slot.fade=.35;slot.level=Levels.RawGain(slot.source) end
end
local function Preload(path)
    if shared.loaded[path]~=nil then return end
    shared.loaded[path]=false
    local state=shared
    local function Ready(sound) if shared==state and sound and sound.length>0 then state.loaded[path]=sound end end
    if cache.GetResourceAsync then cache:GetResourceAsync('Sound',path,Ready)
    else
        local gate=require('app.ResourceGate').New();state.gates[gate]=true
        gate:Start({path},function(ok)
            state.gates[gate]=nil
            if not ok or shared~=state then return end
            state.downloaded[#state.downloaded+1]=path
        end)
    end
end
function M.Dependencies(level)
    local Data=require 'story.MissionData'
    local texts=nil ---@type table<string, boolean>|nil
    if type(level)=='table' then
        texts={}
        local seen={}
        local function Collect(value)
            if type(value)=='string' then texts[Normalize(value)]=true
            elseif type(value)=='table' and not seen[value] then
                seen[value]=true;for _,child in pairs(value) do Collect(child) end
            end
        end
        Collect(level)
    end
    local out={}
    for _,voice in pairs(Data.voices) do
        if not texts then out[#out+1]=voice.path
        else
            for _,text in ipairs(voice.text) do
                if texts[Normalize(text)] then out[#out+1]=voice.path;break end
            end
        end
    end
    for _,name in ipairs({'nono_talk','nono_deadpan','nono_smile','nono_stamp','huhu_talk','huhu_smug','huhu_angry','huhu_flustered'}) do
        out[#out+1]=require('ui.CommsPortrait').Path(name:match('^([^_]+)_'),name)
    end
    out[#out+1]='Story/Boss/chairman_cut.png'
    for _,path in ipairs(require('audio.StoryCommsCues').Dependencies()) do out[#out+1]=path end
    return out
end
function M.New(scene,data,keepOpen)
    if not shared then
        local audioScene=Scene();local root=audioScene:CreateChild('SharedStoryComms')
        shared={scene=audioScene,root=root,slots={},active=0,index={},voices={},loaded={},gates={},downloaded={},decoding={},decodeCursor=1,queue={},time=0}
        shared.cues=require('audio.StoryCommsCues').New()
        for i=1,2 do local source=root:CreateComponent('SoundSource');source:SetSoundType('VoxStoryVoice');shared.slots[i]={source=source} end
    end
    local self=setmetatable({data=data or require('story.MissionData'),log={},source=shared.slots[1].source},M)
    self:Use(keepOpen);return self
end
function M:Owns() return shared~=nil and shared.owner==self and not self.disposed end
function M:Use(keepOpen)
    if self.disposed then return false end
    if shared.owner~=self then
        if shared.owner then shared.owner.resultQuote=nil end
        self.resultQuote=nil
        Fade();shared.card=nil;shared.queue={};shared.owner=self;shared.batchAt=nil;shared.speaker=nil
    end
    shared.keepOpen=keepOpen==true
    for id,voice in pairs(self.data.voices) do
        shared.voices[id]=voice
        for _,text in ipairs(voice.text) do shared.index[Normalize(text)]=id end
    end
    return true
end
function M:Say(lines,urgent,append)
    if not self:Owns() or not lines or #lines==0 then return end
    if not append and self:Talking() and (urgent or shared.time-(shared.batchAt or -math.huge)>1.5) then
        Fade();shared.queue={};shared.card=nil
    end
    shared.batchAt=shared.time
    for _,line in ipairs(lines) do
        shared.queue[#shared.queue+1]=line
        local id=shared.index[Normalize(line[2])];if id then Preload(shared.voices[id].path) end
    end
end
function M:Talking() return self:Owns() and (shared.card~=nil or #shared.queue>0) end
function M:PrepareResultQuote(text)
    if not self:Owns() then return end
    shared.queue={}
    local id=shared.index[Normalize(text)]
    self.resultQuote=id and {id=id,path=shared.voices[id].path,left=.9} or nil
    if self.resultQuote then Preload(self.resultQuote.path) end
end
function M:UpdateResultQuote(dt)
    local quote=self.resultQuote
    if not self:Owns() or not quote or self:Talking() then return end
    local sound=shared.loaded[quote.path]
    if not sound then return end
    quote.left=quote.left-dt
    if quote.left>0 then return end
    self.resultQuote=nil
    shared.active=shared.active==1 and 2 or 1;local slot=shared.slots[shared.active]
    slot.source:StopImmediate();slot.fade=nil;slot.sound=sound;self.source=slot.source
    Levels.Play(slot.source,sound,0,.4);self.log[#self.log+1]=quote.id
end
-- Cinematics retain their authored shot/voice clock while borrowing the card.
function M:Present(who,text,face,time,age,typing,lead,speakEnd)
    if not self:Owns() then return end
    local fresh=not shared.card or shared.speaker~=who
    shared.time=time;shared.speaker=who
    if fresh then shared.enteredAt=time end
    local card=shared.card or {};shared.card=card
    card.who=who;card.text=text;card.face=face;card.age=age;card.typing=typing;card.lead=lead
    card.speakEnd=speakEnd;card.enteredAt=shared.enteredAt;card.length=math.huge
end
function M:FinishLine()
    local card=self.card;if not card then return false end
    card.finishedTyping=true;return true
end
function M:SkipLine()
    local card=self.card;if not card then return false end
    if not card.finishedTyping and card.age<card.typing+(card.lead or 0) then return self:FinishLine() end
    Fade();card.pending=nil;card.speakEnd=0;card.skipped=true;card.age=card.length+1;return true
end
-- App clock owns fades even while the card's owning page is hidden.
function M.Tick(dt)
    require('ui.CommsCard').Tick()
    if not shared then return end
    shared.cues:Update(dt,input.focus and not input.minimized)
    -- Download completion may hold an engine lock; prepare one voice on Update.
    local path=table.remove(shared.downloaded,1)
    if path then
        local sound=cache:GetExistingResource('Sound',path)
        if sound and sound.length>0 then shared.loaded[path]=sound
        else
            cache:BackgroundLoadResource('Sound',path,true)
            shared.decoding[#shared.decoding+1]=path
        end
    end
    -- Legacy Web has no async resource callback: inspect at most four resident
    -- sounds per frame, without ever falling through to synchronous decoding.
    local queue=shared.decoding;local budget=math.min(4,#queue)
    for _=1,budget do
        if #queue==0 then break end
        local index=shared.decodeCursor;local path=queue[index]
        local sound=cache:GetExistingResource('Sound',path)
        if sound and sound.length>0 then
            shared.loaded[path]=sound;queue[index]=queue[#queue];table.remove(queue)
        else shared.decodeCursor=index+1 end
        if shared.decodeCursor>#queue then shared.decodeCursor=1 end
    end
    for _,slot in ipairs(shared.slots) do if slot.fade then
        slot.fade=math.max(0,slot.fade-dt);Levels.SetGain(slot.source,(slot.level or .4)*slot.fade/.35)
        if slot.fade==0 then slot.source:StopImmediate();slot.fade=nil end
    end end
    local speaking=false
    for _,slot in ipairs(shared.slots) do if slot.source.playing and not slot.fade then speaking=true;break end end
    Levels.SetSpeaking(shared,speaking)
end
function M:Update(dt,focus)
    if not self:Owns() then return end
    if not focus then audio:PauseSoundType('VoxStoryVoice');return end
    audio:ResumeSoundType('VoxStoryVoice');dt=math.max(0,dt);shared.time=shared.time+dt
    if not shared.card and #shared.queue>0 then
        local line=table.remove(shared.queue,1);local id=shared.index[Normalize(line[2])]
        local count=utf8.len(line[2]) or #line[2];local typing=count*(line[1]=='boss' and .12 or .032)
        local fresh=shared.speaker~=line[1];shared.speaker=line[1]
        if fresh then shared.cues:Play((line[1]=='huhu' or line[1]=='boss') and 'intercept' or 'open') end
        shared.card={who=line[1],text=line[2],face=line[3],age=0,length=typing+1.8+count*.07,typing=typing,id=id,
            pending=id and shared.voices[id].path,wait=0,enteredAt=fresh and shared.time or shared.enteredAt}
        shared.enteredAt=shared.card.enteredAt
    end
    local card=shared.card;if not card then self:UpdateResultQuote(dt);return end
    if card.pending then
        local sound=shared.loaded[card.pending]
        if sound then
            shared.active=shared.active==1 and 2 or 1;local slot=shared.slots[shared.active]
            slot.source:StopImmediate();slot.fade=nil;slot.sound=sound;self.source=slot.source
            card.pending=nil;card.lead=.26;card.age=0;card.speakEnd=.26+sound.length
            card.length=.26+sound.length+.26+.6;card.typing=math.min(card.typing,sound.length*.85)
            card.sound=sound;card.started=false
        else card.wait=card.wait+dt;if card.wait<=2 then return end;card.pending=nil end
    end
    card.age=card.age+dt
    if card.sound and not card.started and card.age>=card.lead and card.age<card.length then
        card.started=true;Levels.Play(self.source,card.sound,0,.4);self.log[#self.log+1]=card.id
    end
    -- H5 advances subtitles with the focused UI clock. Web SoundSource can
    -- report a frozen zero cursor even while playing; it must not block text.
    if card.age>=card.length and (not shared.keepOpen or #shared.queue>0) then
        shared.card=nil;if #shared.queue==0 then shared.speaker=nil;shared.cues:Play('close') end
    end
    self:UpdateResultQuote(dt)
end
function M:Hide()
    self.resultQuote=nil
    if not self:Owns() then return end
    Fade();shared.card=nil;shared.queue={};shared.speaker=nil
end
function M:Dispose()
    self:Hide();if self:Owns() then shared.owner=nil end;self.disposed=true
end
function M.Shutdown()
    local state=shared
    -- Opening can hand off a portrait before the first tutorial voice exists.
    if not state then require('ui.CommsCard').Dispose();return end
    shared=nil
    Levels.SetSpeaking(state,false)
    state.cues:Dispose()
    for gate in pairs(state.gates) do gate:Cancel() end
    for _,slot in ipairs(state.slots) do slot.source:StopImmediate() end
    state.scene:Dispose();state.card=nil;state.owner=nil
    state.loaded={};state.downloaded={};state.decoding={};state.gates={};state.queue={};state.slots={};state.voices={};state.index={}
    require('ui.CommsCard').Dispose()
end
return M
