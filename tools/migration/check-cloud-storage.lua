local Sync=require 'storage.CloudSync'
local Adapter=require 'storage.CloudStorage'
local function Fixture()
    local state={id='123',reads={},writes={},database={}}
    local transport={}
    function transport:Read(keys,events) state.reads[#state.reads+1]={keys=keys,events=events} end
    function transport:Write(key,text,events) state.writes[#state.writes+1]={key=key,text=text,events=events} end
    local allowed={a=true,b=true}
    local sync=Sync.New{transport=transport,identity=function() return state.id end,user='123',keys={'a','b'},allowed=allowed,
        decode=function(text) local r=cjson.decode(text);return r.v==1 and r or nil end}
    state.sync=sync;state.boots=0
    sync:Start(function(records,reason) state.boots=state.boots+1;state.restored=records;state.reason=reason end)
    function state:Ready(values) self.reads[1].events.ok(values or {}) end
    function state:Ack(index)
        local write=self.writes[index or #self.writes];self.database[write.key]=write.text;write.events.ok()
    end
    return state
end
V.atFrame(55,function()
    local f=Fixture();local s=f.sync
    V.assert(f.boots==0 and s.state=='loading','constructors wait for asynchronous restore')
    V.assert(not s:Queue('a','early'),'no cloud writes before restore')
    f:Ready({a='{"v":1,"data":"saved"}'})
    V.assert(f.boots==1 and f.restored.a.data=='saved','restore completes with saved record')
    V.assert(f.restored.b==nil,'successful missing key remains a new record')
    f:Ready();V.assert(f.boots==1,'duplicate read callback ignored')
    V.assert(s:Queue('a','old') and s:Queue('a','new'),'same-key changes accepted')
    V.assert(s:PendingCount()==1,'debounced changes coalesce')
    s:Update(1);V.assert(#f.writes==1 and f.writes[1].text=='new','only latest local snapshot sent')
    s:Queue('a','latest');s:Queue('b','second');s:Update(2)
    V.assert(#f.writes==1 and s:PendingCount()==3,'active request serializes later writes')
    f:Ack(1);s:Update(1)
    V.assert(#f.writes==2 and f.writes[2].text=='latest','ack cannot discard a newer revision')
    f.writes[1].events.ok();V.assert(s.active~=false,'stale acknowledgment cannot finish newer request')
    f:Ack(2);s:Update(1);f:Ack(3)
    V.assert(f.database.a=='latest' and f.database.b=='second','serial stream reaches final records')
    V.assert(s:PendingCount()==0 and s.notify=='saved','durability notification only after all acknowledgments')
    s:Queue('a','again');V.assert(not s.notify,'new local change clears old durability notification')
    s:Update(1);f.writes[4].events.timeout()
    V.assert(s.state=='blocked' and s.active~=false,'timeout retains unresolved active write')
    V.assert(s:Queue('a','after-timeout'),'edits during uncertain write retained')
    s:Update(100);V.assert(#f.writes==4,'timeout does not retry or advance and risk reordering')
    f:Ack(4);s:Update(1)
    V.assert(s.state=='ready' and #f.writes==5 and f.writes[5].text=='after-timeout','late definitive success safely resumes retained edits')
    f:Ack(5);f.writes[4].events.timeout();V.assert(s.state=='ready','stale timeout cannot block recovered queue')
    s:Stop();f.writes[5].events.ok();s:Update(100)
    V.assert(s.state=='stopped' and #f.writes==5,'stopped writer ignores late callbacks')
    local unknown=Fixture();unknown:Ready()
    V.assert(not unknown.sync:Queue('unknown','x') and unknown.sync.state=='blocked','unsupported save key blocks false durability claims')
    local badValues={false,'not-a-map',{a='broken'},{a='{"v":2}'},{a={v=1}}}
    for _,values in ipairs(badValues) do
        local bad=Fixture();bad.reads[1].events.ok(values)
        V.assert(bad.boots==1 and bad.restored==nil and bad.sync.state=='blocked','malformed cloud read cannot enable defaults upload')
        V.assert(not bad.sync:Queue('a','default'),'failed restore cannot overwrite remote data')
    end
    for _,kind in ipairs({'error','timeout','exception-like'}) do
        local bad=Fixture()
        if kind=='error' then bad.reads[1].events.error(-1,'network')
        elseif kind=='timeout' then bad.reads[1].events.timeout()
        else bad.sync:Update(16) end
        V.assert(bad.boots==1 and bad.restored==nil,'failed or missing read callback allows local startup')
        bad:Ready({a='{"v":1}'});V.assert(bad.sync.state=='blocked' and bad.boots==1,'late read cannot replace edited active vehicle')
    end
    local identity=Fixture();identity.id='456';identity:Ready()
    V.assert(identity.sync.state=='blocked' and identity.restored==nil,'identity change before restore rejected')
    identity=Fixture();identity:Ready();identity.sync:Queue('a','account A');identity.sync:Update(1);identity.id='456'
    identity.sync:Update(1);identity:Ack()
    V.assert(identity.sync.state=='blocked' and not identity.sync:Queue('b','account B'),'account switching halts remote writes and ignores old ack')
    local limited=Fixture();limited:Ready();local writer=limited.sync
    writer:Queue('a','first');writer:Update(1);limited.writes[1].events.error(-429,'throttled')
    V.assert(writer.state=='ready' and writer.active==false,'explicit throttle safely returns request to queue')
    writer:Queue('a','new while throttled');writer:Update(4)
    V.assert(#limited.writes==1,'throttle retry waits')
    writer:Update(1);V.assert(limited.writes[2].text=='new while throttled','throttle retry takes current snapshot')
    limited:Ack();writer:Queue('a','uncertain');writer:Update(1);limited.writes[3].events.error(-1,'unknown')
    writer:Update(60);V.assert(writer.state=='blocked' and #limited.writes==3,'ambiguous network error preserves write ordering')
    local budget=Fixture();budget:Ready();local big=string.rep('x',4*1024*1024)
    local oversized=Fixture();oversized:Ready()
    V.assert(not oversized.sync:Queue('a',big..'x') and oversized.sync.state=='blocked','oversized record rejected before transmission and blocks false confirmation')
    for _=1,4 do budget.sync:Queue('a',big);budget.sync:Update(1);budget:Ack() end
    budget.sync:Queue('b','one');budget.sync:Update(1)
    V.assert(#budget.writes==4,'rolling byte budget prevents transfer bursts')
    budget.sync:Update(60);V.assert(#budget.writes==5,'transfer budget recovers after window')
    local reload=Fixture();reload:Ready(f.database)
    V.assert(reload.sync.state=='blocked','non-schema data is not restored as a valid save')
    local store=require('storage.BlueprintStore').New('vox-validation-cloud')
    local bp=require('construction.Prefab').BuildRaceCar(require('construction.Blueprint').New())
    V.assert(store:SaveSlot(2,bp),'native alternating storage continues to save')
    local data,generation,time,capture=store:LoadSlot(2)
    local envelope={v=1,generation=generation,data=data,time=time,capture=capture}
    local text=cjson.encode(envelope)
    V.assert(Adapter.Decode(text,'vox-save-v1-vox-garage-slot2').data.name==bp.name,'real blueprint validates before hydration')
    local roundtrip=Fixture();roundtrip.sync.options.decode=function(value) return Adapter.Decode(value,'vox-save-v1-vox-garage-slot2') end
    roundtrip:Ready();roundtrip.sync:Queue('a',text);roundtrip.sync:Update(1);roundtrip:Ack()
    local nextSession=Fixture();nextSession.sync.options.decode=roundtrip.sync.options.decode;nextSession:Ready(roundtrip.database)
    V.assert(nextSession.restored.a.data.name==bp.name and nextSession.restored.a.generation==generation,'acknowledged blueprint restores in a fresh writer session')
    local hydrateNamespace='vox-validation-cloud-restored'
    V.assert(require('storage.BlueprintStore').Hydrate(hydrateNamespace,'slot2',envelope),'cloud restoration writes checked local backups')
    local restored=require('storage.BlueprintStore').New(hydrateNamespace)
    local loaded,gen,savedTime=restored:LoadSlot(2)
    V.assert(loaded.name==bp.name and gen==generation and savedTime==time,'vehicle and library metadata survive restore')
    V.assert(restored:DeleteSlot(2),'deletion accepted')
    local empty,tombstone=restored:LoadSlot(2)
    V.assert(empty==nil and tombstone>generation,'deletion persists a generation tombstone')
    local deleted={v=1,generation=tombstone,deleted=true}
    V.assert(Adapter.Decode(cjson.encode(deleted),'vox-save-v1-vox-garage-slot2').deleted,'remote deletion is not an empty-slot omission')
    roundtrip.sync:Queue('a',cjson.encode(deleted));roundtrip.sync:Update(1);roundtrip:Ack()
    nextSession=Fixture();nextSession.sync.options.decode=roundtrip.sync.options.decode;nextSession:Ready(roundtrip.database)
    V.assert(nextSession.restored.a.deleted and nextSession.restored.a.data==nil,'acknowledged deletion survives a fresh cloud session')
    V.assert(require('storage.BlueprintStore').Hydrate(hydrateNamespace,'slot2',deleted),'deletion tombstone restores both backup files')
    V.assert(restored:LoadSlot(2)==nil,'deleted vehicle cannot resurrect from older backup')
    local invalid={v=1,generation=1,data={v=1,active=999}}
    V.assert(not Adapter.Decode(cjson.encode(invalid),'vox-save-v1-vox-garage-garage-state'),'invalid active slot rejected before constructors run')
    invalid.data={step=-1};V.assert(not Adapter.Decode(cjson.encode(invalid),'vox-save-v1-vox-garage-tutorial-v1'),'invalid tutorial state rejected')
    invalid.data={credits=-1,items={},v=1};V.assert(not Adapter.Decode(cjson.encode(invalid),'vox-save-v1-vox-salvage-stash'),'invalid stash rejected')
    invalid.data={quality='bogus',v=2};V.assert(not Adapter.Decode(cjson.encode(invalid),'vox-save-v1-vox-garage-graphics'),'invalid graphics state rejected')
    local inactive=require('storage.BlueprintStore').New('vox-validation-cloud-inactive');inactive:Queue(bp)
    require('storage.BlueprintStore').UpdateAll(.6)
    V.assert(inactive:Read('draft')~=nil and inactive.pending==nil,'inactive lobby store flushes through global pump')
    V.assert(store:SaveMessage('已保存')=='已保存','native save UI remains unchanged')
    local originalWeb,originalSync=Adapter.web,Adapter.sync
    Adapter.web=true;Adapter.sync=false
    V.assert(store:SaveMessage('已保存')=='已保存','QA namespace is excluded from real cloud durability UI')
    V.assert(Adapter.Message('vox-garage','已保存'):find('仅本次会话',1,true)~=nil,'unauthenticated Web save labels actual lifetime')
    Adapter.sync=s
    V.assert(Adapter.Message('vox-garage','已保存'):find('云同步暂停',1,true)~=nil,'blocked Web save never claims cloud durability')
    Adapter.web=originalWeb;Adapter.sync=originalSync
    V.finish()
end)
