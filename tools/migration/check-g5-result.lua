local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Copy(t) if type(t)~='table' then return t end;local out={};for k,v in pairs(t) do out[k]=Copy(v) end;return out end
package.path='scripts/?.lua;'..package.path
package.loaded['core.ResourceData']={Read=function(path) return resources[path] or {} end}
package.loaded['combat.CarUnit']={};package.loaded['salvage.Drops']={}
local Run=require 'salvage.Run'
local Lobby=require 'app.SalvageLobby'
local Loot=require 'salvage.Loot'
local Rules=require 'salvage.RunRules'
local function New(cargo)
    local store={writes=0,fail=false}
    function store:Write(_,data,valid)
        self.writes=self.writes+1;assert(valid(data),'Real stash validator rejects fixture')
        if self.fail then return false,'offline injected save failure' end
        self.saved=Copy(data);return true
    end
    local lobby=setmetatable({store=store,data={v=1,credits=8000,items={scrap=3,cell=4,['part:cube']=4,['part:laser1']=2},stats={raids=0,lost=0,extracted=0}}},Lobby)
    local session={app={salvageLobby=lobby},Pause=function(self) self.pauses=(self.pauses or 0)+1 end}
    local rules=Rules.New({loot={},wrecks={},extracts={}},{vaults=0});rules.cargo=Copy(cargo);rules.time=23;rules.kills=2;rules.openedCount=3
    local run=setmetatable({session=session,rules=rules,cine={},player={alive=true},original={parts={{'core',0,0,0,0},{'cube',0,1,0,0},{'laser1',0,2,0,0}}},runId='result-test'},Run)
    session.salvage=run
    return run,lobby,store,session
end
local function Node(props)
    local n={props=props or {},children={}};for _,child in ipairs(n.props.children or {}) do n.children[#n.children+1]=child end
    function n:AddChild(child) self.children[#self.children+1]=child end
    function n:AddContent(child) self:AddChild(child) end
    function n:SetVisible(value) self.visible=value end
    return n
end
local function Class(props) return Node(props) end
local panel=setmetatable({Extend=function() return setmetatable({},{__call=function(_,props) return Node(props) end}) end},{__call=function(_,props) return Node(props) end})
package.loaded['urhox-libs/UI']={Panel=panel,ScrollView=Node}
package.loaded['ui.SourceDraw']={Number=tostring}
package.loaded['ui.VoxTheme']={};package.loaded['ui.WorkshopPaint']={}
package.loaded['ui.SalvagePaint']={Text=Node};package.loaded['ui.SourceButton']=Node
package.loaded['ui.DialogHost']={Open=function(owner,title,close) local m=Node({text=title});m.close=close;owner.dialog=m;return m end}
local Hud=require 'ui.SalvageRunHud'
local function Texts(node,out)
    out=out or {};if node.props.text then out[#out+1]=tostring(node.props.text) end
    for _,child in ipairs(node.children) do Texts(child,out) end;return out
end
local function Has(list,value) for _,v in ipairs(list) do if v==value then return true end end;return false end
local function Button(node,text)
    if node.props.text==text and node.props.onClick then return node end
    for _,child in ipairs(node.children) do local hit=Button(child,text);if hit then return hit end end
end
local run,lobby,store,session=New({scrap=7,cell=1})
run.hudCargo={{id='cell',n=1},{id='alloy',n=99}};run.hudRefresh=99
Check(run:Finish(true,'撤离',false,{needs='cell'}),'successful paid extraction commits')
Check(run.result.cargo.cell==nil and run.rules.cargo.cell==nil,'paid final token removed from result and finished hold')
Check(run.rules.cargo==run.result.cargo and run.rules.cargo.scrap==7,'finished hold uses retained net result inventory')
Check(lobby.data.items.cell==4 and lobby.data.items.scrap==10,'actual CommitRun credits net loot without returning fee')
Check(run.result.value==Loot.Value({scrap=7}) and run.result.time==23 and run.result.kills==2 and run.result.opened==3,'result value and counters agree with net extracted cargo')
local modal=Hud.Result(session);local texts=Texts(modal)
Check(Has(texts,'废金属') and Has(texts,'×7'),'actual result tree shows newly extracted stock')
Check(not Has(texts,'能量电池') and not Has(texts,'合金板') and not Has(texts,'×99'),'actual result tree ignores consumed token and stale HUD cache')
local writes=store.writes;local result=run.result
Check(run:Finish(true,'repeat',false,{needs='cell'}) and run.result==result and store.writes==writes,'repeated Finish cannot charge fee or credit loot twice')
Button(modal,'回大厅').props.onClick()
Check(session.wantsReturn and store.writes==writes and lobby.data.stats.extracted==1,'actual acknowledged result button returns without another write')
run,lobby,store,session=New({cell=3,scrap=2});run:Finish(true,'撤离',false,{needs='cell'})
Check(run.rules.cargo.cell==2 and run.result.cargo.cell==2 and lobby.data.items.cell==6,'multi-token extraction spends exactly one and retains two')
run.hudCargo={{id='cell',n=3}};texts=Texts(Hud.Result(session))
Check(Has(texts,'×2') and not Has(texts,'×3'),'actual result tree shows post-fee quantity')
run,lobby,store,session=New({cell=1});run:Finish(true,'撤离',false,{needs='cell'});run.hudCargo={{id='cell',n=1}}
texts=Texts(Hud.Result(session))
Check(next(run.result.cargo)==nil and run.result.value==0 and Has(texts,'两手空空') and not Has(texts,'能量电池'),'token-only extraction renders empty result after paying fee')
for _,keep in ipairs({false,true}) do
    run,lobby,store,session=New({scrap=7,cell=1});local lost=Loot.Value(run.rules.cargo)
    Check(run:Finish(false,keep and '放弃行动' or '战车被击毁',keep),'actual loss commits keepCar '..tostring(keep))
    Check(next(run.rules.cargo)==nil and next(run.result.cargo)==nil and run.result.value==0,'actual loss clears both inventories keepCar '..tostring(keep))
    Check(lobby.data.items.scrap==3 and lobby.data.items.cell==4 and lobby.data.items['part:cube']==(keep and 4 or 3),'actual loss gives no loot and applies original part policy keepCar '..tostring(keep))
    Check(run.result.lost==lost+(keep and 0 or resources['UI/Outgame.json'].items['part:cube'].price+resources['UI/Outgame.json'].items['part:laser1'].price),'loss amount captured before clearing hold keepCar '..tostring(keep))
    texts=Texts(Hud.Result(session))
    Check(not Has(texts,'废金属') and Has(texts,keep and '货舱里的东西全丢了，战车开回来了。' or '战车零件和货舱里的东西全丢了。蓝图还在车库里，缺的零件回大厅补买。'),'actual loss modal shows source policy keepCar '..tostring(keep))
end
run,lobby,store,session=New({scrap=7,cell=2});local old=lobby.data;store.fail=true;run.hudCargo={{id='cell',n=2}}
Check(not run:Finish(true,'撤离',false,{needs='cell'}) and lobby.data==old,'failed write restores original stash object')
Check(run.result.cargo.cell==1 and run.rules.cargo.cell==1 and not run.committed,'failed write retains exact already-paid net result')
modal=Hud.Result(session);texts=Texts(modal)
Check(Has(texts,'×1') and Has(texts,'offline injected save failure'),'failed-save result tree shows retained net count and failure')
local retry=Button(modal,'重试保存');Check(retry~=nil,'actual failed result exposes retry command')
retry.props.onClick()
Check(not session.wantsReturn and lobby.data==old and run.result.cargo.cell==1,'failed retry stays on result and does not spend token again')
store.fail=false;retry.props.onClick()
Check(session.wantsReturn and run.committed and lobby.data.items.cell==5 and lobby.data.items.scrap==10,'actual retry button commits net cargo once then returns')
writes=store.writes;retry.props.onClick();Check(store.writes==writes and lobby.data.stats.extracted==1 and lobby.data.items.cell==5,'repeated retry callback is transaction-idempotent')
return checks
