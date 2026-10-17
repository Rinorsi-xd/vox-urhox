local checks={}
local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local function Copy(t) if type(t)~='table' then return t end;local out={};for k,v in pairs(t) do out[k]=Copy(v) end;return out end
package.path='scripts/?.lua;'..package.path
dofile('tools/migration/g5-offline-imports.lua').Salvage()
dofile('tools/migration/g5-offline-imports.lua').Exclude({'construction.Prefab','construction.Blueprint','construction.Garage','ui.SourceButtonMotion','ui.SalvageLootMotion'})
package.loaded['core.ResourceData']={Read=function(p)return resources[p] or {}end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={}
local Run=require 'salvage.Run'
local Lobby=require 'app.SalvageLobby'
local Rules=require 'salvage.RunRules'
local Return=require 'salvage.ResultReturn'
local function Node(p)
    local n={props=p or {},children={}};for _,c in ipairs(n.props.children or {})do n.children[#n.children+1]=c end
    function n:AddChild(c)self.children[#self.children+1]=c end
    function n:AddContent(c)self:AddChild(c)end
    function n:SetVisible(v)self.visible=v end
    return n
end
local panel=setmetatable({Extend=function()return setmetatable({},{__call=function(_,p)return Node(p)end})end},{__call=function(_,p)return Node(p)end})
package.loaded['urhox-libs/UI']={Panel=panel,ScrollView=Node}
package.loaded['ui.SourceDraw']={Number=tostring};package.loaded['ui.VoxTheme']={};package.loaded['ui.WorkshopPaint']={}
package.loaded['ui.SalvagePaint']={Text=Node};package.loaded['ui.SourceButton']=Node
package.loaded['ui.DialogHost']={Open=function(owner,title,close)local m=Node({text=title});m.close=close;owner.dialog=m;return m end,
    Close=function(owner)local m=owner.dialog;if m then owner.dialog=nil;m.close()end end,
    Dispose=function(owner)local m=owner.dialog;if m then owner.dialog=nil;m.close()end end}
local Hud=require 'ui.SalvageRunHud'
local driveAim=assert(load(driveAimClearSource,'@actual-DriveAim.Clear','t',{}))()
local TrialDispose=assert(load(trialDisposeSource,'@actual-TrialSession.Dispose','t',{M={},Host=package.loaded['ui.DialogHost'],DriveAim=driveAim}))()
local function Button(n,text)if n.props.text==text and n.props.onClick then return n end;for _,c in ipairs(n.children)do local b=Button(c,text);if b then return b end end end
local function New(fixture,fail)
    local store={writes=0,fail=fail}
    function store:Write(_,data,valid)self.writes=self.writes+1;assert(valid(data));if self.fail then return false,'injected save failure' end;self.saved=Copy(data);return true end
    local app={mode='trial',scene={},loader={state='ready'},loadingFlow={active=false}}
    local lobby=setmetatable({store=store,data={v=1,credits=8000,items={scrap=3,cell=4,['part:cube']=4,['part:laser1']=2},stats={raids=1,lost=0,extracted=0},lastStartedRun='return-test'}},Lobby)
    app.salvageLobby=lobby
    local session={app=app,Pause=function(self)self.paused=true end};app.trial=session
    local r=Rules.New({loot={},wrecks={},extracts={}},{vaults=0});r.cargo={scrap=7,cell=2};r.time=23;r.kills=2;r.openedCount=3
    local run=setmetatable({session=session,rules=r,begun=true,cine={Dispose=function()end},entries={},world={units={},Dispose=function()end},player={alive=true,Position=function()return {0,0,0}end},
        original={parts={{'core',0,0,0,0},{'cube',0,1,0,0},{'laser1',0,2,0,0}}},runId='return-test'},Run)
    session.salvage=run
    session.combat=run;session.world=run.world;session.scene={};session.effects={Dispose=function()end};session.view={Dispose=function()end}
    return run,lobby,store,session,app,{app=app}
end
for _,f in ipairs(fixtures.cases)do
    local run,lobby,store,session,app,owner=New(f)
    local state=Hud.Attach(session,Node())
    if f.kind=='success' then run:Finish(true,'从「出口」撤离',false,{needs='cell'})
    elseif f.kind~='abandon' then run:Finish(false,f.result.title,false) end
    if f.kind~='abandon' then
        Check(not session.dialog and not session.wantsReturn,'no result modal over live '..f.kind)
        state.Update(.249);Check(not session.wantsReturn,'source 250ms delay retained '..f.kind)
        state.Update(.0011);Check(session.wantsReturn,'finished result requests automatic return '..f.kind)
    end
    Check(run:Return(),'return not gated on old result acknowledgement '..f.kind)
    local p=app.pendingSalvageResult;local writes=store.writes
    Check(p and p.result~=run.result and p.originalParts~=run.original.parts and not p.session,'detached result data '..f.kind)
    Check(p.result.ok==f.result.ok and p.result.title==f.result.title and p.result.value==f.result.value and p.result.lost==f.result.lost,'source result values '..f.kind)
    for id,n in pairs(f.stock)do Check((lobby.data.items[id] or 0)==n,'source stock '..f.kind..' '..id)end
    Check(lobby.data.stats.lost==f.stats.lost and lobby.data.stats.extracted==f.stats.extracted,'source outcome counters '..f.kind)
    run:Return();Check(app.pendingSalvageResult==p and store.writes==writes,'repeat return does not duplicate settlement '..f.kind)
    local opens=0;local function Show(...)opens=opens+1;return Hud.Result(...)end
    Return.Update(app,owner,1,Show);Check(opens==0,'live battle cannot show hall result '..f.kind)
    TrialDispose(session);Return.RecordRelease(app,session)
    Check(run.session==nil and run.world==nil and p.result.title==f.result.title,'actual Dispose leaves detached result valid '..f.kind)
    for key,value in pairs(p.release)do Check(value,'actual TrialSession.Dispose releases '..f.kind..' '..key)end
    app.trial=nil;app.mode='hangar';app.loadingFlow.active=true
    Return.Update(app,owner,1,Show);Check(opens==0,'loading cover defers hall result '..f.kind)
    app.loadingFlow.active=false;app.loader.state='loading'
    Return.Update(app,owner,1,Show);Check(opens==0,'scene loader defers hall result '..f.kind)
    app.loader.state='ready';owner.dialog={}
    Return.Update(app,owner,1,Show);Check(opens==0,'existing hall modal is not replaced '..f.kind)
    owner.dialog=nil
    Return.Update(app,owner,f.kind=='abandon' and .199 or 0,Show)
    if f.kind=='abandon' then Check(opens==0,'abandon 200ms result delay retained');Return.Update(app,owner,.0011,Show)end
    Check(opens==1 and owner.dialog~=nil and not session.dialog,'hall owns result modal '..f.kind)
    Return.Update(app,owner,1,Show);Check(opens==1,'hall result opens once '..f.kind)
    local button=Button(owner.dialog,'回大厅');Check(button~=nil,'source acknowledgement command '..f.kind)
    button.props.onClick()
    Check(owner.dialog==nil and app.pendingSalvageResult==nil and not owner.wantsReturn and store.writes==writes,'acknowledgement only closes hall result '..f.kind)
end
KEY_ESCAPE='Escape';KEY_T='KeyT';KEY_SPACE='Space';KEY_E='KeyE';KEY_F='KeyF';KEY_N='KeyN';KEY_BACKSPACE='Backspace';KEY_RETURN='Enter'
for _,control in ipairs(fixtures.controls)do
    local run=New({});local skips=0
    run.cine={blocking=true,current={name=control.name},Skip=function()if control.name=='drop'then skips=skips+1 end end}
    Check(run:Key(control.code)==control.consumed,'frozen blocking key contract '..control.name..' '..control.code)
    Check(skips==control.skips,'source drop-only skip behavior '..control.name..' '..control.code)
end
for _,shot in ipairs({'drop','extract','death','none'})do
    local run,lobby,store,session,app=New({});local released=0
    if shot~='none'then run.cine.current={name=shot};run.cine.playing=true;run.cine.ReleaseCar=function()released=released+1 end end
    -- Reload does not call Run.Return; execute the actual enclosing session disposer.
    TrialDispose(session);Return.RecordRelease(app,session)
    local p=app.pendingSalvageResult
    Check(p and p.result.title=='放弃行动' and p.result.keepCar and p.committed,'direct reload dispose settles begun raid '..shot)
    Check(store.writes==1 and lobby.data.stats.lost==1 and lobby.data.items['part:cube']==4,'direct reload loss commits once without vehicle loss '..shot)
    Check(session.paused~=true and p.release.disposed and p.release.world and p.release.combat,'disposal never pauses retired audio and records release '..shot)
    Check(released==(shot=='none' and 0 or 1),'held cinematic body released before disposal '..shot)
    TrialDispose(session);Check(store.writes==1,'repeated session disposal cannot count loss twice '..shot)
end
do
    local run,lobby,store,session,app=New({});run:Finish(true,'撤离',false,{needs='cell'})
    local result=run.result;local writes=store.writes
    TrialDispose(session);Return.RecordRelease(app,session)
    Check(app.pendingSalvageResult.result.ok and app.pendingSalvageResult.result.cargo.cell==1 and store.writes==writes and lobby.data.stats.lost==0,'reload inside finish delay retains success without abandonment')
end
do
    local run,lobby,store,session,app=New({});run.begun=false
    TrialDispose(session);Check(app.pendingSalvageResult==nil and store.writes==0 and lobby.data.stats.lost==0,'unbegun cancelled preparation never records abandoned raid')
end
for _,kind in ipairs({'success','death','abandon'})do
    local run,lobby,store,session,app,owner=New({},true);local before=lobby.data
    if kind~='abandon'then run:Finish(kind=='success',kind,false,kind=='success' and {needs='cell'} or nil)end
    Check(run:Return(),'save failure still leaves live battle '..kind)
    local p=app.pendingSalvageResult
    Check(not p.committed and p.saveError and lobby.data==before,'failed settlement retained with original economy '..kind)
    local cargo=Copy(p.result.cargo);run:Dispose();app.trial=nil;app.mode='hangar'
    Return.Update(app,owner,1,Hud.Result)
    local button=Button(owner.dialog,'重试保存');Check(button~=nil,'hall failure exposes retry '..kind)
    button.props.onClick();Check(owner.dialog~=nil and app.pendingSalvageResult==p and lobby.data==before,'failed retry preserves pending result '..kind)
    for id,n in pairs(cargo)do Check(p.result.cargo[id]==n,'retry never charges extraction fee twice '..kind..id)end
    -- Hall ESC/owner close cannot discard an unsaved settlement.
    local host=package.loaded['ui.DialogHost'];host.Close(owner)
    Check(app.pendingSalvageResult==p and not p.shown,'unsaved result close remains pending '..kind)
    Return.Update(app,owner,0,Hud.Result);button=Button(owner.dialog,'重试保存')
    store.fail=false;button.props.onClick()
    Check(owner.dialog==nil and app.pendingSalvageResult==nil and p.committed,'successful retry closes only after commit '..kind)
    local writes=store.writes;button.props.onClick()
    Check(store.writes==writes and lobby.data.stats.extracted==(kind=='success' and 1 or 0) and lobby.data.stats.lost==(kind=='success' and 0 or 1),'repeat acknowledgement is economy-idempotent '..kind)
end
return checks
