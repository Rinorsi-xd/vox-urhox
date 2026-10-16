package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local touch=false
local blocked=false
local soundLog={}
local radioPaths={'Story/Radio/Radio.json','Story/Radio/match_found_b.wav','Story/Radio/missile_close_a.wav',
 'Story/Radio/objective_loss_a.wav','Story/Radio/loot_pickup_a.wav','Story/Radio/objective_gain_b.wav',
 'Story/Radio/urgent_warning_a.wav','Story/Radio/match_victory_a.wav'}
package.preload['audio.StoryCommsCues']=function() return {Dependencies=function() return radioPaths end} end
package.preload['audio.UiSound']=function() return {Play=function(id) soundLog[#soundLog+1]=id;return true end} end
local hud={tab='hangar'}
hud.SetTab=function(tab) hud.tab=tab end
package.preload['urhox-libs/UI']=function() return {GetFocus=function() end} end
package.preload['core.ResourceData']=function() return {Read=function() return TEST_DATA end} end
package.preload['controls.TouchMode']=function() return {Enabled=function() return touch end} end
package.preload['ui.GarageHud']=function() return {GetState=function() return hud end,IsBlocked=function() return blocked end} end
package.preload['app.ResourceGate']=function() return {New=function() return {state='ready',Cancel=function() end,
 Start=function(self,paths,callback) self.paths=paths;self.state='ready';callback(true) end} end} end
package.preload['ui.TutorialPage']=function() return {New=function() return {CancelInput=function() end,Close=function() end,Destroy=function() end} end} end
package.preload['audio.StoryComms']=function()
    return {New=function()
        local voice={log={},source={playing=false},own=true,sayCount=0,hideCount=0,pauseCount=0}
        function voice:Owns() return self.own end
        function voice:Use() self.own=true end
        function voice:Say(lines)
            self.sayCount=self.sayCount+1;self.said=lines
            local line=lines[1]
            self.card={text=line[2],who=line[1],face=line[3],age=0,typing=utf8.len(line[2])*.032,length=100}
        end
        function voice:Update(dt,focus)
            if not focus then self.pauseCount=self.pauseCount+1;return end
            if self.card then self.card.age=self.card.age+dt end
        end
        function voice:FinishLine() self.card.finishedTyping=true end
        function voice:Hide() self.hideCount=self.hideCount+1;self.card=nil end
        function voice:Dispose() self.own=false;self.card=nil end
        return voice
    end}
end
input={focus=true,minimized=false,GetKeyPress=function() return false end}
local Rules=require 'story.TutorialRules'
local Tutorial=require 'story.Tutorial'
local parts=30
local toasts={}
local writes={}
local app={scene={},stopped=false,isValidation=true,blueprint={Size=function() return parts end},
    bays={active=false,unsaved=true},loader={state='ready'},loadingFlow={active=false},vehicleGate={state='ready'},
    store={Read=function() end,Write=function(_,key,record) writes[#writes+1]=record;return true end},
    toasts={Push=function(_,text,kind,ms) toasts[#toasts+1]={text=text,kind=kind,ms=ms} end}}
function app:EnterBuild() self.build={} end
local t=Tutorial.New(app)
t.gate.state='idle';t:Prepare()
local prepared={};for _,path in ipairs(t.gate.paths) do prepared[path]=true end
for _,path in ipairs(radioPaths) do Check(prepared[path],'tutorial preloads communications feedback '..path) end
Check(#TEST_DATA.steps==16,'all sixteen authored steps loaded')
local voices=0;for _ in pairs(TEST_DATA.voices) do voices=voices+1 end
Check(voices==18,'all eighteen original recordings retained')
local overrideCount=0
for _,spec in ipairs(TEST_DATA.steps) do
    t.rules.flow={spec.id};t.rules.index=1
    touch=false;Check(t:Lines()==spec.lines,'PC dialogue '..spec.id)
    Check(t:Hint()==spec.hint,'PC hint '..spec.id)
    touch=true;Check(t:Lines()==(spec.touchLines or spec.lines),'touch dialogue '..spec.id)
    Check(t:Hint()==(spec.touchHint or spec.hint),'touch hint '..spec.id)
    if spec.touchLines then overrideCount=overrideCount+1 end
end
Check(overrideCount==4,'exact four source mobile dialogue overrides')
local function Begin(index,path)
    t.initialized=true;t.rules:Start(index,path,t:State());t.revision=-1;t:Update(.01)
end
for _,mode in ipairs({false,true}) do
    touch=mode;Begin(1,'build')
    local first=TEST_DATA.steps[1].lines[1][2]
    Check(t.visible and t.voice.card.text==first,'real update displays initial authored dialogue')
    local index=t.rules.index;t:Advance()
    Check(t.line==1 and t.voice.card.finishedTyping and t.rules.index==index,'first click finishes text without skipping')
    t:Advance();t:Update(.01)
    Check(t.line==2 and t.voice.card.text==TEST_DATA.steps[1].lines[2][2],'second click advances queued authored line')
    t:Advance();t:Advance();t:Update(.01)
    Check(t.rules:StepSpec().id=='car','final manual click advances authored step')
    Begin(5,'build')
    Check(t.voice.card.text==(mode and t.rules:StepSpec().touchLines or t.rules:StepSpec().lines)[1][2],
        'real update sends correct device-specific bag text to audio card')
    Check(t.voice.said[1][3]=='nono_talk','source portrait is retained')
end
touch=false;Begin(1,'build');t:Advance();t:Advance();t:Update(.01)
local before=t.voice.sayCount
blocked=true;t:Update(.01)
Check(not t.visible and t.voice.card==nil,'modal hides the owned tutorial card')
blocked=false;t:Update(.01)
Check(t.line==1 and t.voice.sayCount==before+1,'modal resume replays authored step from first line')
Check(t.voice.card.text==TEST_DATA.steps[1].lines[1][2],'modal resume does not continue stale middle sentence')
local hidden=t.voice.hideCount;local paused=t.voice.pauseCount
input.focus=false;t:Update(.01)
Check(t.voice.pauseCount==paused+1 and t.voice.hideCount==hidden,'OS focus pause preserves current speech rather than modal replay')
input.focus=true;t:Update(.01)
Check(t.visible and t.voice.hideCount==hidden,'OS focus resumes the same card')
local function State()
    return {parts=30,build=false,inventory=false,saved=false,home=true,tab='hangar',drive=false,mission=false}
end
local function FinishCondition(r,a)
    r:Tick(.01,a,false);Check(r.doneAt~=false,'condition observed '..r:StepSpec().id)
    r:Tick(.44,a,false);Check(r.running,'completion hold does not end early')
    r:Tick(.02,a,false)
end
local r=Rules.New(TEST_DATA,nil,function() end)
local a=State();r:Start(1,nil,a)
for _=1,3 do Check(r:Advance(a),'intro manual explanation advances') end
Check(r:StepSpec().id=='choose','intro reaches route choice')
a.build=true;FinishCondition(r,a)
Check(r.path=='build' and r:StepSpec().id=='bag','actual editor entry selects build route')
r:Tick(1,a,false);Check(r:StepSpec().id=='bag','closed inventory cannot satisfy open instruction')
a.inventory=true;FinishCondition(r,a);Check(r:StepSpec().id=='pick','bag open reaches picker')
a.inventory=false;FinishCondition(r,a);Check(r:StepSpec().id=='place','picker close snapshots current parts')
r:Tick(1,a,false);Check(r:StepSpec().id=='place','selection alone cannot satisfy placement')
a.parts=31;FinishCondition(r,a);Check(r:StepSpec().id=='save','real part-count change reaches save')
r:Tick(1,a,false);Check(r:StepSpec().id=='save','unsaved vehicle does not advance')
a.saved=true;FinishCondition(r,a);Check(r:StepSpec().id=='back','saved slot reaches return')
a.build=false;FinishCondition(r,a);Check(r:StepSpec().id=='battle','hall return reaches battle')
a.tab='battle';FinishCondition(r,a);Check(r:StepSpec().id=='story','battle tab reaches story')
a.tab='story';FinishCondition(r,a);Check(r:StepSpec().id=='go','story page reaches mission entry')
a.drive=true;r:Tick(2,a,true);Check(r.running,'ordinary driving does not complete story lesson')
a.mission=true;r:Tick(.01,a,true);Check(not r.running and r.record.done,'actual mission completes build route while hidden')
a=State();r:Start(4,nil,a);a.tab='battle';FinishCondition(r,a)
Check(r.path=='drive' and r:StepSpec().id=='story','battle choice selects drive route')
a.tab='story';FinishCondition(r,a);a.drive=true;a.mission=true;r:Tick(.01,a,true);r:Tick(5,a,true)
Check(r:StepSpec().id=='go','hidden mission cannot expose debrief')
a.drive=false;r:Tick(.01,a,false);Check(r:StepSpec().id=='debrief','return reveals authored debrief')
Check(r:Advance(a),'debrief advances manually');a.tab='hangar';FinishCondition(r,a)
Check(r:StepSpec().id=='edit','drive route returns to editing instruction')
a.build=true;FinishCondition(r,a);a.inventory=true;FinishCondition(r,a);a.inventory=false;FinishCondition(r,a)
a.parts=31;FinishCondition(r,a);a.saved=true;FinishCondition(r,a);a.build=false;FinishCondition(r,a)
Check(r:StepSpec().id=='graduate','drive route includes authored graduation')
Check(r:Advance(a) and not r.running and r.record.done,'full drive route completes after graduation')
for _,path in ipairs({'intro','build','drive'}) do
    for index=1,#TEST_DATA.flows[path] do
        local resumed=Rules.New(TEST_DATA,{step=index-1,path=path=='intro' and nil or path})
        Check(resumed:Resume(State()),'resume accepts persisted '..path..' step '..index)
        Check(resumed.running and resumed:StepSpec()~=nil,'resumed step exists')
    end
end
local restarted=Rules.New(TEST_DATA,{step=6,path='build'})
restarted:Resume(State());Check(restarted:StepSpec().id=='choose','build resume outside editor cannot strand inventory instruction')
for _,record in ipairs({{step=-1},{step=1.5},{step=0,path='bad'}}) do Check(not Rules.ValidRecord(record),'malformed resume record rejected') end
Begin(1,'build');t:Skip();Check(t.rules.running and t.skipConfirm==3,'first skip only asks confirmation')
t:Update(3.1);t:Skip();Check(t.rules.running,'expired skip confirmation cannot skip')
t:Skip();Check(not t.rules.running and t.rules.record.skipped,'second skip persists authored skip')
Check(toasts[#toasts].text=='已跳过新手引导，暂停菜单里可以重新播放','skip toast matches source')
local keep=t.rules.record;t:Replay();t:Update(.01);t:Skip()
Check(not t.rules.running and t.rules.record==keep,'replay skip preserves main progress')
t:Replay();t:Update(.01)
for _,change in ipairs({{inventoryPanel={}},{inventoryPanel=false}}) do
    app.build=app.build or {};app.build.inventoryPanel=change.inventoryPanel or nil
    for _=1,7 do t:Update(.1) end
end
parts=parts+1;for _=1,7 do t:Update(.1) end
app.bays.active='slot1';app.bays.unsaved=false;for _=1,7 do t:Update(.1) end
Check(not t.rules.running and t.rules.record==keep,'production replay completes without changing progress')
Check(toasts[#toasts].text=='拼装教学看完了' and toasts[#toasts].kind=='ok' and toasts[#toasts].ms==2000,'natural replay completion restores exact source toast')
local function ResetSounds() for i=#soundLog,1,-1 do soundLog[i]=nil end end
if TEST_SOURCE then
    app.build=nil;app.trial=nil;app.bays.active=false;app.bays.unsaved=true;hud.tab='hangar';blocked=false
    for _,case in ipairs(TEST_SOURCE.advances) do
        Begin(1,'build');ResetSounds()
        local lines=t:Lines();local state=case.state
        t.line=state.talking and #state.queue>0 and 1 or #lines
        t.lineAge=state.talking and not state.typed and 0 or 1e9
        t.voice.card.finishedTyping=not state.talking or state.typed
        t:Advance()
        Check(#soundLog==#case.sounds,'actual manual Advance matches frozen JS sound count')
        for i,id in ipairs(case.sounds) do Check(soundLog[i]==id,'actual manual Advance cue matches frozen JS') end
    end
    for _,case in ipairs(TEST_SOURCE.conditions) do
        app.trial=nil;hud.tab='hangar';blocked=false
        local id=case.observeHidden and 'go' or 'battle';local index
        for i,step in ipairs(TEST_DATA.flows.build) do if step==id then index=i end end
        Begin(index,'build');ResetSounds()
        t.rules.doneAt=case.doneAt and t.rules.elapsed or false
        if case.observeHidden then app.trial=case.got and {story={}} or nil
        else hud.tab=case.got and 'battle' or 'hangar';blocked=case.busy end
        t:Update(.01)
        Check(#soundLog==#case.sounds,'actual condition/hidden gate matches frozen JS sound count')
        for i,cue in ipairs(case.sounds) do Check(soundLog[i]==cue,'actual condition cue matches frozen JS') end
    end
    app.trial=nil;blocked=false;hud.tab='hangar';Begin(4,'intro');ResetSounds()
    t:Choose('drive');Check(soundLog[1]=='press' and #soundLog==1 and hud.tab=='battle','route choice press precedes original battle action')
    t.visible=false;ResetSounds();t:Choose('build');t:Advance();Check(#soundLog==0,'hidden tutorial cannot generate press')
end
return {result='PASS',checks=checks,voices=voices,steps=#TEST_DATA.steps,touchDialogueOverrides=overrideCount,
    boundary='Actual Lua Tutorial and TutorialRules with native-free UI/audio actors; no runtime visual, account or real-device acceptance.'}
