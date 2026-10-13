local UI=require 'urhox-libs/UI'
local Rules=require 'story.TutorialRules'
local M={};M.__index=M
function M.New(app)
    local self=setmetatable({},M);self:init(app);return self
end
function M:init(app)
    self.app=app;self.visible=false;self.initialized=false;self.disposed=false;self.revision=-1
    local data=require('core.ResourceData').Read('UI/Tutorial.json')
    self.data=data;self.voice=nil ---@type table|nil
    self.rules=Rules.New(data,app.store:Read('tutorial-v1',Rules.ValidRecord),function(r)
        local ok,err=app.store:Write('tutorial-v1',r,Rules.ValidRecord);if not ok then print('[Tutorial] '..err) end
    end)
    self.page=require('ui.TutorialPage').New(self)
    self.gate=require('app.ResourceGate').New()
end
function M:State()
    local a=self.app;local h=require('ui.GarageHud').GetState();local b=a.build
    return {parts=a.blueprint:Size(),build=b~=nil,inventory=b and b.inventoryPanel~=nil or false,
        saved=a.bays.active~=nil and a.bays.active~=false and not a.bays.unsaved,
        tab=h and h.tab or '',home=h~=false and h~=nil,drive=a.trial~=nil,mission=a.trial and a.trial.story~=nil or false}
end
function M:Busy(state)
    local a=self.app;local b=a.build
    return not a.scene or a.stopped or not input.focus or input.minimized or a.mapPreview~=nil or state.drive or
        a.loader.state=='loading' or a.loadingFlow.active or a.vehicleGate.state=='loading' or
        require('ui.GarageHud').IsBlocked() or b and b.dialog~=nil or a.lobby=='salvage' or self.gate.state=='loading'
end
function M:Prepare()
    if self.gate.state=='idle' or self.gate.state=='failed' then
        local paths={'UI/Faces/nono_talk.png','UI/Faces/nono_deadpan.png','UI/Faces/nono_smile.png'}
        for _,v in pairs(self.data.voices) do paths[#paths+1]=v.path end
        self.gate:Start(paths,function(ok,message)
            if not ok then print('[Tutorial] Portrait download failed: '..tostring(message)) end
        end)
    end
end
function M:Start() self.initialized=true;self.rules:Start(1,nil,self:State());self.revision=-1 end
function M:Replay() self.initialized=true;self.rules:Replay(self:State());self.revision=-1 end
function M:Advance()
    if not self.visible or self.rules:StepSpec().next~='button' then return end
    local s=self.rules:StepSpec();local line=s.lines[self.line]
    local count=utf8.len(line[2]);local duration=self.typing or count*.032
    if self.lineAge<duration then
        self.lineAge=duration
        if self.voice and self.voice.card then self.voice.card.age=duration end
    elseif self.line<#s.lines then self.line=self.line+1;self.lineAge=0
    else self.rules:Advance(self:State()) end
end
function M:Skip()
    if self.rules.replay then self.rules:Stop();return end
    if self.skipConfirm and self.skipConfirm>0 then
        self.rules:Stop(true);self.app.toasts:Push('已跳过新手引导，暂停菜单里可以重新播放','info',3200)
    else self.skipConfirm=3 end
end
function M:Choose(path)
    if not self.visible or not self.rules:StepSpec().choice then return end
    if path=='build' then self.app:EnterBuild()
    else local h=require('ui.GarageHud').GetState();if h then h.SetTab('battle') end end
end
function M:Update(dt)
    if self.disposed then return end
    local state=self:State();local busy=self:Busy(state)
    if not self.initialized and not busy then
        self.initialized=true
        if not self.rules:Resume(state) and not self.app.isValidation and not rawget(_G,'VOX_SKIP_TUTORIAL') and
            not self.rules.record.done and not self.rules.record.skipped then self.rules:Start(1,nil,state) end
    end
    self.rules:Tick(math.min(dt,.1),state,busy)
    if self.rules.running then self:Prepare();busy=self:Busy(state) end
    self.visible=self.rules.running and not busy
    if self.skipConfirm then self.skipConfirm=math.max(0,self.skipConfirm-dt) end
    if self.revision~=self.rules.revision then self.revision=self.rules.revision;self.line=1;self.lineAge=0;self.skipConfirm=0 end
    if not self.visible then
        self.page:CancelInput();if self.voice then self.voice:Hide();self.voiceKey=false end
        return
    end
    local s=self.rules:StepSpec();local line=s.lines[self.line]
    if not self.voice then self.voice=require('audio.StoryComms').New(self.app.scene,self.data,true) end
    local key=self.rules.revision..':'..self.line
    if self.voiceKey~=key then self.voiceKey=key;self.voice:Say({line},true) end
    self.voice:Update(math.min(dt,.1),true)
    local card=self.voice.card;self.typing=card and card.typing or utf8.len(line[2])*.032
    self.lineAge=card and card.age or 0
    local length=card and card.length or utf8.len(line[2])*.102+1.8
    if self.line<#s.lines and self.lineAge>length then self.line=self.line+1;self.lineAge=0 end
end
function M:Keys()
    if not self.visible then return false end
    local focus=UI.GetFocus();if focus and focus.OnTextInput then return false end
    if self.rules:StepSpec().next=='button' and (input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN)) then self:Advance();return true end
    return not self.app.build and input:GetKeyPress(KEY_G)
end
function M:Snapshot()
    return {running=self.rules.running,visible=self.visible,id=self.rules:StepSpec() and self.rules:StepSpec().id,
        path=self.rules.path,index=self.rules.index,total=#self.rules.flow,replay=self.rules.replay,
        record=self.rules.record,card=self.page.cardRect,target=self.page.targetRect,buttons=self.page.buttons,line=self.line,lineAge=self.lineAge,
        voicePlayed=self.voice and #self.voice.log or 0,voicePlaying=self.voice and self.voice.source.playing or false,
        voiceId=self.voice and self.voice.card and self.voice.card.id}
end
function M:DetachVoice()
    if self.voice then self.voice:Dispose();self.voice=nil end;self.voiceKey=false
end
function M:Dispose()
    self:DetachVoice()
    self.disposed=true;self.gate:Cancel();self.page:Close();self.page:Destroy()
end
return M
