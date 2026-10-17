local Lobby=require('app.SalvageLobby')
local Store=require('storage.BlueprintStore')
local Run=require('salvage.Run')
local Rules=require('salvage.RunRules')
local Loot=require('salvage.Loot')
local Read=require('core.ResourceData').Read
local data=Read('Salvage/RunData.json')
local gp=Read('Salvage/Gameplay.json')
local function Same(a,b)
    for k,v in pairs(a) do if b[k]~=v then return false end end
    for k,v in pairs(b) do if a[k]~=v then return false end end;return true
end
V.atFrame(10,function()
    local namespace='vox-salvage-settle-'..os.time()..'-'..math.random(1000000)
    local parts={{'cube',0,2,0,1},{'laser1',0,3,0,1},{'core',0,4,0,1}}
    local function New(kind)
        local store=Store.New(namespace..'-'..kind)
        local stash=setmetatable({store=store,data={v=1,credits=8000,items={['part:cube']=4,['part:laser1']=2,scrap=3},stats={raids=0,lost=0,extracted=0}}},Lobby)
        assert(stash:Save())
        local pauses=0;local session={app={salvageLobby=stash},Pause=function() pauses=pauses+1 end}
        local run=setmetatable({session=session,original={parts=parts},runId=kind,rules=Rules.New(gp,data.ops[1],function() return .4 end),cine={},player={alive=true}},Run)
        run.rules.cargo={scrap=7,drive=1};run.rules.time=20;run.rules.kills=2;run.rules.openedCount=3
        return run,stash,store,function() return pauses end
    end
    local extract,stash,store,pauses=New('extract')
    local drops=0;extract.cine.Drop=function() drops=drops+1 end
    extract:Begin();extract:Begin()
    V.assert(drops==1 and stash.data.stats.raids==1 and stash.data.lastStartedRun=='extract','actual Begin persists source raid count and runs drop once')
    local begun=store:Read('stash',Lobby.Valid)
    V.assert(begun.stats.raids==1 and begun.lastStartedRun=='extract' and not begun.lastRun,'interrupted raid is already counted before result in real store')
    V.assert(stash:BeginRun('extract') and stash.data.stats.raids==1,'repeated begin run ID cannot count raid twice')
    V.assert(extract:Finish(true,'撤离',false,{needs='drive'}),'actual Finish commits successful extraction')
    V.assert(stash.data.items.scrap==10 and not extract.result.cargo.drive and stash.data.items['part:laser1']==2,'extraction pays token and adds cargo without losing installed car')
    V.assert(extract.result.value==Loot.Value({scrap=7}) and extract.result.kills==2 and extract.result.opened==3 and pauses()==1,'actual extraction value/report/pause contract')
    V.assert(extract:Commit() and stash.data.stats.raids==1 and stash.data.stats.extracted==1,'duplicate finish does not duplicate extracted cargo/stats')
    local restored=Store.New(store.namespace or namespace..'-extract'):Read('stash',Lobby.Valid)
    V.assert(restored and restored.items.scrap==10 and restored.lastRun=='extract','actual two-generation store reopens acknowledged extracted result')
    local resumed=setmetatable({store=store,data=restored},Lobby)
    V.assert(resumed:CommitRun('extract',extract.result,parts) and resumed.data.items.scrap==10 and resumed.data.stats.raids==1,'reloaded settlement run ID prevents double credit')
    local encoded=cjson.encode({v=1,generation=1,data=restored})
    local decoded=require('storage.CloudStorage').Decode(encoded,'vox-save-v1-vox-salvage-stash')
    V.assert(decoded and Same(decoded.data.items,restored.items),'actual cloud record validation preserves acknowledged settlement')
    local dead,loss,lossStore=New('death');dead.player.alive=false
    dead.rules:Step(.1,{alive=false})
    local event=dead.rules:Drain()[1]
    V.assert(event and event.type=='failed' and dead.rules.finished,'actual death rule reaches failed result')
    V.assert(dead:Finish(false,event.reason,false),'death loss commits')
    V.assert(loss.data.items['part:cube']==3 and loss.data.items['part:laser1']==1 and loss.data.items.scrap==3 and loss.data.credits==8000,'death drops cargo and exactly one copy of each original car part')
    V.assert(dead.result.lost==Loot.Value({scrap=7,drive=1})+Read('UI/Outgame.json').items['part:cube'].price+Read('UI/Outgame.json').items['part:laser1'].price,'death reports original full-car plus cargo value')
    V.assert(lossStore:Read('stash',Lobby.Valid).stats.lost==1 and dead:Return(),'persisted death result permits return')
    local timeout,expired=New('timeout');timeout.rules.time=899.99
    timeout.rules:Step(.02,{alive=true,pos={99999,0,99999},speed=0,width=5})
    V.assert(timeout.rules.finished and timeout.rules:Drain()[1].type=='failed','actual 900-second limit reaches failed result')
    V.assert(timeout:Finish(false,'超时',false) and expired.data.items['part:laser1']==1 and expired.data.stats.lost==1,'time limit applies same committed full-car loss')
    local abandon,kept=New('abandon')
    V.assert(abandon:Return() and abandon.result.keepCar==true and abandon.result.title=='放弃行动' and abandon.session.app.pendingSalvageResult.runId=='abandon','return while running retains abandonment result for returned hall')
    V.assert(kept.data.items['part:laser1']==2 and kept.data.items.scrap==3 and kept.data.stats.lost==1 and abandon:Return(),'abandonment loses cargo, retains car and repeated return cannot settle twice')
    local retry,failed,failedStore=New('retry');local previous=failed.data;local save=failed.Save
    failed.Save=function() return false,'injected failed write' end
    retry.cine.Drop=function() end;retry:Begin()
    V.assert(retry.begun and failed.data==previous and failed.data.stats.raids==0,'failed begin save preserves stored count, allows drop and defers count to commit')
    V.assert(not retry:Finish(true,'撤离',false) and failed.data==previous and retry.saveError~=nil,'failed settlement save restores complete original data object')
    V.assert(failedStore:Read('stash',Lobby.Valid).items.scrap==3 and retry:Return() and not retry.session.app.pendingSalvageResult.committed,'failed settlement returns with detached retry and does not leak cargo into storage')
    failed.Save=save
    V.assert(retry.session.app.pendingSalvageResult:Commit() and failed.data.items.scrap==10 and failed.data.stats.raids==1,'returned hall retries detached result and commits exactly once')
    V.assert(retry:Return() and failed.data.items.scrap==10 and failed.data.stats.raids==1,'repeated return remains idempotent')
    V.assert(not Lobby.Valid({v=1,credits=0,items={},lastStartedRun=12}),'cloud/local validator rejects corrupt begun run ID')
    V.finish()
end)
