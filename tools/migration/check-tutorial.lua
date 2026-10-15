local app=nil ---@type HangarApp|nil
local stage='boot'
local function Logic()
    local Rules=require 'story.TutorialRules';local data=require('core.ResourceData').Read('UI/Tutorial.json')
    V.assert(#data.steps==16 and #data.flows.build==12 and #data.flows.drive==15 and #data.flows.replay==4,'exact frozen tutorial steps and four route lengths')
    local saved={};local r=Rules.New(data,nil,function(v) saved[#saved+1]=cjson.encode(v) end)
    local a={parts=30,build=false,inventory=false,saved=false,home=true,tab='hangar',drive=false,mission=false}
    r:Start(1,nil,a);V.assert(r:StepSpec().id=='hello' and r.record.step==0,'source zero-based record begins at welcome')
    r:Tick(2,a,false);V.assert(r.index==1,'manual explanation does not skip itself')
    for i=1,3 do r:Advance(a) end
    V.assert(r:StepSpec().id=='choose','intro reaches player route choice')
    a.build=true;r:Tick(.1,a,false);r:Tick(.46,a,false)
    V.assert(r.path=='build' and r:StepSpec().id=='bag','real edit entry chooses build-first route')
    r:Tick(.8,a,false);V.assert(r:StepSpec().id=='bag','closed bag cannot satisfy opening condition')
    a.inventory=true;r:Tick(.1,a,false);r:Tick(.46,a,false);V.assert(r:StepSpec().id=='pick','open inventory advances once')
    a.inventory=false;r:Tick(.1,a,false);r:Tick(.46,a,false);V.assert(r:StepSpec().id=='place','closing picker captures current part count')
    r:Tick(1,a,false);V.assert(r:StepSpec().id=='place','hovering or choosing cannot count as assembly')
    a.parts=31;r:Tick(.1,a,false);r:Tick(.46,a,false);V.assert(r:StepSpec().id=='save','actual count change satisfies assembly')
    r:Tick(1,a,false);V.assert(r:StepSpec().id=='save','unsaved draft cannot satisfy saving')
    a.saved=true;r:Tick(.1,a,false);r:Tick(.46,a,false);V.assert(r:StepSpec().id=='back','successful slot write advances')
    a.build=false;r:Tick(.1,a,false);r:Tick(.46,a,false);V.assert(r:StepSpec().id=='battle','return starts combat lesson')
    a.tab='battle';r:Tick(.1,a,false);r:Tick(.46,a,false);a.tab='story';r:Tick(.1,a,false);r:Tick(.46,a,false)
    V.assert(r:StepSpec().id=='go','source story selection advances to mission entry')
    a.drive=true;a.mission=false;r:Tick(1,a,true);V.assert(r.running,'ordinary trial does not finish story lesson')
    a.mission=true;r:Tick(.1,a,true);V.assert(not r.running and r.record.done,'build-first tutorial completes hidden at actual mission entry')
    a.drive=false;a.mission=false;a.tab='hangar';r:Start(4,nil,a);a.tab='battle';r:Tick(.1,a,false);r:Tick(.46,a,false)
    V.assert(r.path=='drive' and r:StepSpec().id=='story','battle entry chooses drive-first route')
    a.tab='story';r:Tick(.1,a,false);r:Tick(.46,a,false);a.drive=true;a.mission=true;r:Tick(.1,a,true);r:Tick(6,a,true)
    V.assert(r:StepSpec().id=='go','hidden gameplay cannot leak next lesson')
    a.drive=false;r:Tick(.1,a,false);V.assert(r:StepSpec().id=='debrief','return resumes drive-first debrief')
    r:Advance(a);a.tab='hangar';r:Tick(.1,a,false);r:Tick(.46,a,false);V.assert(r:StepSpec().id=='edit','source story back resumes edit lesson')
    local keep=cjson.encode(r.record);r:Replay(a);a.build=true
    for _,changes in ipairs({{inventory=true},{inventory=false},{parts=32},{saved=true}}) do
        for k,v in pairs(changes) do a[k]=v end;r:Tick(.1,a,false);r:Tick(.46,a,false)
    end
    V.assert(not r.running and cjson.encode(r.record)==keep,'editor replay completes without changing main tutorial progress')
    local restart=Rules.New(data,{step=6,path='build'});restart:Resume(a)
    V.assert(restart:StepSpec().id=='choose','restart outside build cannot strand tutorial inside inventory')
    restart:Stop(true);V.assert(restart.record.skipped and not restart:Resume(a),'skip persistently prevents automatic resume')
    V.assert(not Rules.ValidRecord({step=-1}) and not Rules.ValidRecord({step=1.5}) and not Rules.ValidRecord({step=0,path='unknown'}),'malformed tutorial records rejected')
    local nativeInput=input;local pressed={};local built,removed=0,0
    local editor={tool='build',pasting=false,Remove=function() removed=removed+1 end}
    local session={editor=editor,buildCamera={captured=true,touch=false,buttonsReady=true},Trace=function() end,Act=function() built=built+1 end}
    local controls=require('controls.BuildInput').New(session)
    input={GetMouseButtonDown=function() return false end,GetMouseButtonPress=function(_,button) return pressed[button]==true end}
    pressed[MOUSEB_LEFT]=true;controls:FirstPerson(.016);pressed={}
    controls:FirstPerson(.016)
    pressed[MOUSEB_RIGHT]=true;controls:FirstPerson(.016);controls:FirstPerson(.016);pressed={}
    controls:FirstPerson(.016);input=nativeInput
    V.assert(built==1 and removed==2 and controls.pointer==nil,'short source pointerdown edits survive down/up between frames and distinct repeated presses')
    local View=require('render.CombatView').New(app.scene)
    local dead={alive=false,vehicle=nil,externalView=false,bp={}};local binds=0;local disposed=0
    View.units[dead]={Bind=function() binds=binds+1 end,Dispose=function() disposed=disposed+1 end}
    View:Consume({viewEvents={{type='unitRebuilt',unit=dead},{type='unitKilled',unit=dead}},debris={events={}}})
    V.assert(binds==0 and disposed==1 and not View.units[dead],'queued rebuild then kill never binds disposed vehicle')
    View:Consume({viewEvents={{type='unitSpawn',unit=dead},{type='unitKilled',unit=dead}},debris={events={}}})
    V.assert(not View.units[dead],'queued spawn then kill never creates a view of disposed vehicle')
    local sync=require 'combat.PlayerViewSync';local visible={enabled=true};sync.Update({player=dead,session={view={view={root=visible}}},world={viewEvents={{type='unitRebuilt',unit=dead},{type='unitKilled',unit=dead}}}})
    V.assert(not visible.enabled,'same event ordering hides destroyed player without rebinding freed physics')
end
local function Poll()
    if stage=='boot' and VOX_HANGAR then
        app=VOX_HANGAR.app
        app.store=require('storage.BlueprintStore').New('vox-tutorial-test-'..os.time());app.bays.store=app.store
        app.bays.active=false;app.bays.unsaved=true
        Logic();app.tutorial:Start();stage='hello'
    elseif stage=='hello' then
        local t=app.tutorial;t:Update(.1);t.visible=true
        for i=1,3 do t.visible=true;t.line=#t.rules:StepSpec().lines;t.lineAge=120;t:Advance();t:Update(.1) end
        t.visible=true
        V.assert(t.rules:StepSpec().id=='choose','production source card advances to route choice')
        t:Choose('build');V.assert(app.build~=nil,'tutorial choice enters production editor');stage='build'
    elseif stage=='build' then
        local t=app.tutorial;t.rules:Tick(.5,t:State(),false);t:Update(.1)
        if t.rules:StepSpec().id~='bag' then return end
        app.build:OpenInventory();t.rules:Tick(.1,t:State(),false);t.rules:Tick(.46,t:State(),false)
        V.assert(t.rules:StepSpec().id=='pick' and app.build.inventoryPanel~=nil,'production inventory opening satisfies actual lesson')
        app.build.inventoryPanel:Close();t.rules:Tick(.1,t:State(),false);t.rules:Tick(.46,t:State(),false)
        V.assert(t.rules:StepSpec().id=='place','real picker closing starts assembly lesson')
        local e=app.editor;e.mirror=false;e:SelectType('cube')
        local found=false
        for _,p in ipairs(e.bp:List()) do for _,c in ipairs(p._cells) do if not found then
            e:Preview({hit=true,partId=p.id,cell=c,place={c[1],c[2]+1,c[3]},normal={0,1,0}})
            if e.preview and e.preview.res.ok then found=e:Place() end
        end end end
        V.assert(found,'production connected cube placement changes vehicle')
        t.rules:Tick(.1,t:State(),false);t.rules:Tick(.46,t:State(),false)
        V.assert(t.rules:StepSpec().id=='save','actual vehicle change completes assembly')
        V.assert(app.build:SaveSlot(),'real tutorial vehicle saved to garage')
        t.rules:Tick(.1,t:State(),false);t.rules:Tick(.46,t:State(),false)
        V.assert(t.rules:StepSpec().id=='back','actual successful save satisfies lesson')
        app:ExitBuild();t.rules:Tick(.1,t:State(),false);t.rules:Tick(.46,t:State(),false)
        V.assert(t.rules:StepSpec().id=='battle','real return retains tutorial across UI replacement')
        t:Replay();local record=cjson.encode(t.rules.record);t:Skip()
        V.assert(not t.rules.running and cjson.encode(t.rules.record)==record,'replay skip preserves actual progress')
        t:Start();t.visible=true;t:Skip();V.assert(t.rules.running,'first skip click only asks confirmation');t:Skip()
        V.assert(t.rules.record.skipped and not t.rules.running,'second skip click records skip')
        local persisted=app.store:Read('tutorial-v1',require('story.TutorialRules').ValidRecord)
        V.assert(persisted.skipped,'native tutorial record read back from recoverable storage')
        stage='done';V.finish()
    end
end
for frame=40,500 do V.atFrame(frame,Poll) end
V.atFrame(505,function() V.assert(stage=='done','tutorial lifecycle complete');V.finish() end)
