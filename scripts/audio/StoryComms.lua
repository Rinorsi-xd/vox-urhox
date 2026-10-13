local M={};M.__index=M
local function Normalize(text)
    local out={};text=text:gsub('^【[^】]*】','')
    for _,code in utf8.codes(text) do
        if code>=0x3400 and code<=0x9fff or code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122 then out[#out+1]=utf8.char(code) end
    end
    return table.concat(out)
end
function M.Dependencies()
    local Data=require 'story.MissionData'
    local out={};for _,voice in pairs(Data.voices) do out[#out+1]=voice.path end
    for _,name in ipairs({'nono_talk','nono_deadpan','nono_smile','huhu_talk','huhu_smug','huhu_angry','huhu_flustered'}) do out[#out+1]='UI/Faces/'..name..'.png' end
    return out
end
function M.New(scene,data,keepOpen)
    data=data or require('story.MissionData')
    local root=scene:CreateChild('StoryComms');local source=root:CreateComponent('SoundSource');source:SetSoundType('VoxStoryVoice')
    local index={};for id,voice in pairs(data.voices) do for _,text in ipairs(voice.text) do index[Normalize(text)]=id end end
    return setmetatable({root=root,source=source,index=index,data=data,keepOpen=keepOpen,queue={},time=0,log={}},M)
end
function M:Say(lines,urgent)
    if not lines or #lines==0 then return end
    if self:Talking() and (urgent or self.time-(self.batchAt or -math.huge)>1.5) then self.queue={};self.card=nil;self.fade=.35 end
    self.batchAt=self.time;for _,line in ipairs(lines) do self.queue[#self.queue+1]=line end
end
function M:Talking() return self.card~=nil or #self.queue>0 end
function M:Update(dt,focus)
    if not focus then self.source:StopImmediate();return end
    self.time=self.time+dt
    if self.fade then self.fade=self.fade-dt;self.source.gain=math.max(0,self.fade/.35)*.7;if self.fade>0 then return end;self.fade=nil;self.source:StopImmediate() end
    if not self.card and #self.queue>0 then
        local line=table.remove(self.queue,1);local id=self.index[Normalize(line[2])];local sound=id and cache:GetResource('Sound',self.data.voices[id].path)
        local count=utf8.len(line[2]) or #line[2];local length=sound and sound.length or count*.102+1.8
        self.card={who=line[1],text=line[2],face=line[3],age=0,length=length+.6,typing=math.min(count*.032,length*.85),id=id}
        if sound then self.source:Play(sound,0,.7);self.log[#self.log+1]=id end
    end
    if self.card then self.card.age=self.card.age+dt;if self.card.age>=self.card.length and (not self.keepOpen or #self.queue>0) then self.card=nil end end
end
function M:Hide() self.source:StopImmediate();self.card=nil;self.queue={};self.fade=nil end
function M:Dispose() self.source:StopImmediate();self.root:Dispose();self.card=nil;self.queue={} end
return M
