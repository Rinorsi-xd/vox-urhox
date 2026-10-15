local Radio=require 'audio.StoryRadio'
local data=Radio.Data()
V.atFrame(2,function()
    V.assert(data.source.commit=='2b169a9964645f5f346a7158bcb14447f040814a','radio frozen October 14 identity')
    V.assert(#Radio.Dependencies()==8,'seven originals and source manifest declared')
    local expected={open={'match_found',.38,.25,0,.5},close={'missile_close',.3,.2,8.7,.18},intercept={'objective_loss',.5,.23,7.4,.4},pickup={'loot_pickup',1,.16,10.7,.14},install={'objective_gain',.85,.23,14.5,.4},alert={'urgent_warning',.7,.24,15.2,1.2},done={'match_victory',1,.27,10.1,.5}}
    local audio=Radio.New();audio.focus=function()return true end;local scene=audio.scene
    for name,want in pairs(expected) do
        local cue=data.cues[name];local gain=want[3]*10^(want[4]/20)*want[2]*.65
        V.assert(cue.id==want[1] and cue.strength==want[2] and cue.gap==want[5],'source radio cue identity strength gap '..name)
        V.assert(math.abs(audio:Gain(name)-gain)<1e-8,'source calibrated gain '..name)
        V.assert(audio.sounds[name].length>0,'original waveform decodes '..name)
        audio:Update(2,true);V.assert(audio:Play(name),'real retained source plays '..name)
        V.assert(not audio:Play(name),'original gap suppresses duplicate '..name)
        local slot=audio.slots[#audio.slots];if slot and slot.id==cue.id then V.assert(math.abs(slot.source.gain-gain)<1e-6,'native source calibrated gain '..name) end
    end
    audio:Update(2,true);audio:Play('pickup');local slots=#audio.slots
    audio:Update(.15,true);audio:Play('pickup');audio:Update(.15,true);audio:Play('pickup');audio:Update(.15,true);audio:Play('pickup')
    local same=0;for _,slot in ipairs(audio.slots) do if slot.source.playing and slot.id=='loot_pickup' then same=same+1 end end
    V.assert(same<=3 and #audio.slots<=10,'bounded source same cue three total ten voices')
    audio:Update(.1,false);V.assert(not audio:Play('done'),'focus gate suppresses cue')
    local stopped=true;for _,slot in ipairs(audio.slots) do if slot.source.playing then stopped=false end end
    V.assert(stopped,'focus loss stops native playing sources')
    audio:Update(2,true);V.assert(scene==audio.scene and audio:Play('done'),'UI transition keeps audio scene and buffers')
    audio.volume=0;audio:Update(.1,true);V.assert(not audio:Play('pickup'),'zero volume suppresses new sound')
    audio:Dispose();audio:Dispose();V.assert(audio.disposed and #audio.slots==0 and not audio:Play('done'),'idempotent sound scene cleanup')
    local boss=require 'combat.StoryBoss';local calls={};local events={}
    local fixture=setmetatable({radio={Play=function(_,name)calls[#calls+1]=name end},rules={Drain=function()local out=events;events={};return out end},mission={rules={}},step={title='test'},Fx=function()end,Banner=function()end}, {__index=boss})
    for _,state in ipairs({'stomp','slamCrouch','sweep','lanes','ult'}) do events={{type='state',state=state}};fixture:Events();V.assert(calls[#calls]=='alert','real Boss dispatch original attack warning '..state) end
    local n=#calls;events={{type='state',state='recover'},{type='state',state='fight'}};fixture:Events();V.assert(#calls==n,'recovery and fight do not invent radio warnings')
    events={{type='nodeBreak',pos={0,0,0}},{type='phase',phase=2}};fixture:Events();V.assert(#calls==n+2,'real Boss node and phase radio dispatch')
    local UI=require 'urhox-libs/UI';local root=UI.Panel{width='100%',height='100%'};local scene=Scene();local page=require('ui.Epilogue').Attach(scene,root,nil,{})
    local played={};local play=page.radio.Play;page.radio.Play=function(self,name)played[#played+1]=name;return play(self,name)end
    page.rules.events={{kind='panel',panel={deal=true}}};page:Update(.01,true)
    V.assert(played[1]=='pickup' and #page.dealCues==1,'real Epilogue panel plays original pickup')
    page:Update(1.59,true);V.assert(#played==1,'contract install waits source 1.6 seconds')
    page:Update(.02,true);V.assert(played[2]=='install','contract install plays at authored timer')
    page.rules.events={{kind='stamp'}};page:Update(0,true);V.assert(played[3]=='done','epilogue rejection stamp plays original done')
    page:Dispose();root:Destroy();scene:Dispose();V.assert(page.radio.disposed and #page.dealCues==0,'epilogue cancels pending sounds on cleanup')
    V.finish()
end)
