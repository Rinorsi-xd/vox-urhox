-- Isolated QA suffix: observe real consumers without changing mission state or input.
do
local attached=nil
local pending={}
local open=nil
local sequence=0
local function Record(kind,fields)
    if not open then return end
    fields=fields or {};fields.kind=kind;fields.ruleTime=attached.rules.time
    open.calls[#open.calls+1]=fields
end
local function Attach(m)
    attached=m
    local banner=m.Banner
    m.Banner=function(self,kick,title,sub,kind,ms,...)
        local result=banner(self,kick,title,sub,kind,ms,...)
        if kick=='检查点' then
            sequence=sequence+1
            local t=self.convoy
            open={sequence=sequence,checkpoint=t.cp,failures=self.rules.stats.fails,
                mission=self.level.id,ruleTime=self.rules.time,worldTime=app.trial.world.time,
                d=t.d,total=t.total,hp=t.hp,cpD=t.cpD,cpHp=t.cpHp,calls={}}
            pending[#pending+1]=open
            Record('Banner',{kick=kick,title=title,sub=sub,style=kind,ms=ms})
        end
        return result
    end
    local play=m.radio.Play
    m.radio.Play=function(self,cue,...)
        local result=play(self,cue,...)
        local playing=false
        for _,slot in ipairs(self.slots)do
            if slot.order==self.order and slot.source and slot.source.playing then playing=true end
        end
        Record('radio',{cue=cue,accepted=result==true,playing=playing})
        return result
    end
    local say=m.voice.Say
    m.voice.Say=function(self,lines,urgent,...)
        local result=say(self,lines,urgent,...)
        Record('say',{lines=lines or {},urgent=urgent==true,queue=#self.queue})
        return result
    end
    print('CONVOY_CHECKPOINT_ATTACHED '..cjson.encode({mission=m.level.id}))
end
local update=HandleUpdate
function HandleUpdate(...)
    update(...)
    local m=app and app.trial and app.trial.story
    if m and m~=attached then
        assert(m.level.id=='s2','Convoy checkpoint observer requires actual public S2 entry')
        Attach(m)
    elseif not m then attached=nil end
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
    post(...)
    for _,record in ipairs(pending)do print('CONVOY_CHECKPOINT_CONSUMERS '..cjson.encode(record))end
    pending={};open=nil
end
end
