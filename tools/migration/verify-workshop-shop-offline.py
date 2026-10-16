"""Run frozen H5 shop methods and actual Lua page/purchase modules, no GPU."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
oracle = json.loads(subprocess.check_output(['node', 'tools/migration/workshop-shop-oracle.cjs'], text=True, encoding='utf-8'))
baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
assert oracle['baseline']['commit'] == baseline['commit'] == 'b276064942ae09c0227ec28d4cfda1d5ff006455'
lua = LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if isinstance(value, dict):
        return lua.table_from({k: convert(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(v) for v in value])
    return value

resources = {}
for file in ['UI/Outgame.json', 'UI/Workshop.json', 'UI/SalvageRules.json', 'Parts/Catalog.json']:
    resources[file] = json.loads((ROOT / 'assets' / file).read_text(encoding='utf-8'))
source_items = json.loads(subprocess.check_output(['node', 'tools/migration/workshop-source-items.mjs'], text=True, encoding='utf-8'))
assert resources['UI/Outgame.json']['items'] == source_items['items'], 'All shipped item metadata must equal frozen source'
assert resources['UI/SalvageRules.json'] == source_items['rules'], 'All shipped stash rules must equal frozen source'
lua.globals().RESOURCES = convert(resources)
lua.globals().ORACLE = convert(oracle)
lua.execute(r'''
package.path='scripts/?.lua;'..package.path
CHECKS=0
function Check(value,message) CHECKS=CHECKS+1;assert(value,message) end
package.preload['core.ResourceData']=function() return {Read=function(path) return RESOURCES[path] end} end
local Shop=require 'ui.WorkshopShop'
local Data=RESOURCES['UI/Workshop.json']
for id,cost in pairs(ORACLE.prices) do Check(Shop.Price(id)==cost,'actual prefab price '..id) end
for _,expected in ipairs(ORACLE.order) do
    local list={};for _,p in ipairs(Data.prefabs) do if expected.group=='all' or p.group==expected.group then list[#list+1]=p end end
    Shop.Sort(list,expected.sort,Data.stats,true)
    Check(#list==#expected.ids,'sort cardinality')
    for i,p in ipairs(list) do Check(p.id==expected.ids[i],'frozen source sort '..expected.group..'/'..expected.sort..'/'..i) end
end
for _,expected in ipairs(ORACLE.refresh) do
    local state=Shop.State({app={lobby='salvage',salvageLobby={data={credits=expected.wallet}}}},expected.id)
    Check(state.cost==expected.cost and state.wallet==expected.wallet and state.poor==expected.poor,'source affordability '..expected.id)
end
Check(Shop.State({app={lobby='arena'}},'scorpion')==nil,'arena has no economy adapter')
Check(Shop.Label('empty',true,true)=='免费领取','source free chassis detail label')
Check(Shop.Label('empty',false,true)=='购买整车','source feature purchase label')
Check(Shop.Label('empty',true,false)=='放进新车位，开始搭','source creative chassis detail label')
Check(Shop.Label('rat',true,false)=='放进新车位','source creative label')

-- Only native widget/layout/render APIs are substituted. Workshop, Card,
-- Button, Shop, ShopPaint, SalvageBuy and StashRules remain actual Lua modules.
local function Class(parent)
    local c={};c.__index=c
    setmetatable(c,{__index=parent,__call=function(k,props)
        local o=setmetatable({props=props or {},children={},state={hovered=false}},k)
        if o.Init then o:Init(o.props) end
        for _,child in ipairs(o.props.children or {}) do o:AddChild(child) end
        return o
    end})
    function c:Extend() return Class(self) end
    return c
end
local Base=Class()
function Base:Init(props) self.props=props end
function Base:AddChild(child) self.children[#self.children+1]=child;child.parent=self;return child end
function Base:InsertChild(child,index) table.insert(self.children,index,child);child.parent=self end
function Base:RemoveChild(child) for i,c in ipairs(self.children) do if c==child then table.remove(self.children,i);break end end end
function Base:SetStyle(style) for k,v in pairs(style) do self.props[k]=v end end
function Base:SetDisabled(value) self.props.disabled=value end
function Base:SetVisible(value) self.props.visible=value;return self end
function Base:IsVisible() return self.props.visible~=false end
function Base:SetText(text) self.props.text=text end
function Base:GetAbsoluteLayout() return {x=self.props.left or 0,y=self.props.top or 0,w=type(self.props.width)=='number' and self.props.width or 500,h=type(self.props.height)=='number' and self.props.height or 40} end
function Base:Update() end
function Base:RenderBackgroundImage() end
local UI={Panel=Base,Label=Base,ScrollView=Base,GetNVGContext=function() return 1 end,GetViewportSize=function() return 1920,1080 end}
package.preload['urhox-libs/UI']=function() return UI end
package.preload['urhox-libs/UI/Widgets/Button']=function() return Base end
DRAW={}
local function Number(n) local text=tostring(math.floor(n));return text:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','') end
local D={orange={122,216,255,255},white={237,246,255,255},ink={8,15,28,255},muted={145,172,200,255}}
for _,name in ipairs({'Begin','Path','Rect','Line','Gradient','Panel','Icon'}) do D[name]=function() end end
function D.Width(_,text,size) return (utf8.len(tostring(text)) or 0)*size*.6 end
D.Number=Number;D.Color=function(c) return c end
function D.Text(_,text,...) DRAW[#DRAW+1]={text=tostring(text),args={...}} end
package.preload['ui.SourceDraw']=function() return D end
package.preload['ui.SourceRelief']=function() return {Draw=function() end} end
local Paint={colors={{1,2,3},{1,2,3},{1,2,3},{1,2,3},{1,2,3}},textShadows={}}
for _,name in ipairs({'Image','Radial','Glow','Sweep','TrimImages','Tier','Segments'}) do Paint[name]=function() end end
Paint.NameShadows=function() return {} end
Paint.Bars=function() return {} end
Paint.Meta=function(id) return {stats=Data.stats[id],blueprint={bb={minX=0,maxX=10,minY=0,maxY=5,minZ=0,maxZ=12}},items={}} end
package.preload['ui.WorkshopPaint']=function() return Paint end
package.preload['ui.SourceParagraph']=function() return {New=function() return {Measure=function() return {height=60} end,Draw=function() end} end} end
local Carousel={ids=Data.featured}
for _,name in ipairs({'Leave','Mount','Keep','Render','Step'}) do Carousel[name]=function() end end
Carousel.Target=function(ws) return ws.selected end
Carousel.Select=function(s,id) s.workshop.selected=id;s.revision=-1 end
Carousel.Ready=function() return true end
Carousel.Caption=function() return 1,0 end;Carousel.Shelf=Carousel.Caption
package.preload['ui.WorkshopCarousel']=function() return Carousel end
package.preload['ui.WorkshopEntrance']=function() return {Start=function() end,Step=function() end,Group=function() return 1,0,0 end,Fill=function() return 1 end} end
package.preload['ui.VoxTheme']=function() return {Thumbnail=function() return '' end} end
package.preload['ui.GarageDialogs']=function() return {Code=function(s,importing) s.codeOpened=importing end} end
package.preload['ui.SalvagePage']=function() return {Tab=function(s,tab) s.salvage.tab=tab end} end
for _,name in ipairs({'nvgSave','nvgRestore','nvgBeginPath','nvgRect','nvgIntersectScissor','nvgFillColor','nvgFill','nvgTranslate','nvgRotate','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgArc','nvgScale','nvgGlobalAlpha','nvgFillPaint'}) do _G[name]=function() end end
nvgRGBA=function(...) return {...} end;nvgBoxGradient=function() return {} end
NVG_ALIGN_RIGHT=1;NVG_ALIGN_CENTER=2;NVG_CCW=1
YGNodeCalculateLayout=function() end;YGNodeLayoutGetHeight=function() return 500 end
KEY_ESCAPE=1;KEY_BACKSPACE=2;KEY_RETURN=3;KEY_KP_ENTER=4;KEY_RIGHT=5;KEY_LEFT=6
PRESSED={};input={GetKeyPress=function(_,key) return PRESSED[key] or false end}
graphics={GetWidth=function() return 1920 end,GetDPR=function() return 1 end}
local Workshop=require 'ui.Workshop'
local function Owner(shop,view,id)
    local s={width=1920,height=1080,usedCount=1,salvage={tab='workshop'},revision=0,workshop={view=view,selected=id or 'rat',group='all',sort='rec',elapsed=0},
        app={lobby=shop and 'salvage' or 'arena',salvageLobby={data={credits=8000}},HomeView=function() end},Track=function(w) return w end,
        workshopPreview={auto=true,Show=function() end,SetAuto=function() end,Reset=function() end}}
    s.CreateVehicle=function(id) s.purchased=id end
    return s
end
local function TextExists(page,text)
    for _,w in ipairs(page.children) do if w.props.text==text then return w end end
end
local s=Owner(true,'feature','fox');local page=Workshop.Create(s)
Check(page.shop and page.purchaseButtons[1].props.text=='购买整车','actual shop feature has purchase label')
Check(page.purchaseButtons[1].props.shop.cost==44828 and page.purchaseButtons[1].props.shop.poor,'actual poor feature state')
Check(not page.purchaseButtons[1].props.disabled,'poor state still allows warehouse alternative confirmation')
Check(not TextExists(page,'导入蓝图') and not TextExists(page,'分享当前战车'),'salvage hides creative import/export')
Check(TextExists(page,'查看全部')~=nil,'salvage preserves browse action')
Check(#page.shopCards==5 and page.shopCards[1].shop.cost==43112,'feature shelf carries prices')
s.app.salvageLobby.data.credits=50000;page:Update(0)
Check(not page.purchaseButtons[1].props.shop.poor and not page.shopCards[1].shop.poor,'wallet changes refresh button and card affordability')
local cached=page.purchaseButtons[1].props.shop;page:Update(0);Check(cached==page.purchaseButtons[1].props.shop,'stable wallet avoids per-frame shop table allocation')
page.purchaseButtons[1].props.onClick();Check(s.purchased=='fox','feature action selects actual prefab purchase')
DRAW={};page:Render(1);local wallet=false;for _,d in ipairs(DRAW) do if d.text=='50,000' then wallet=true end end;Check(wallet,'source wallet is drawn')
for _,card in ipairs(page.shopCards) do card:Render(1) end
local creative=Owner(false,'feature','fox');local normal=Workshop.Create(creative)
Check(TextExists(normal,'导入蓝图') and TextExists(normal,'分享当前战车'),'arena keeps both sharing actions')
Check(not normal.purchaseButtons[1].props.shop and normal.purchaseButtons[1].props.text=='放进新车位','arena has no price/economy')
TextExists(normal,'导入蓝图').props.onClick();Check(creative.codeOpened==true,'creative import action remains connected')
for _,id in ipairs({'rat','empty'}) do
    local detailOwner=Owner(true,'detail',id);local detail=Workshop.Create(detailOwner)
    Check(detail.purchaseButtons[1].props.text==(id=='empty' and '免费领取' or '购买整车'),'actual detail purchase/free label '..id)
    DRAW={};detail:Render(1);local price=false;for _,row in ipairs(DRAW) do if row.text=='整车价格' then price=true end end;Check(price,'detail renders fourth price fact')
    detail.purchaseButtons[1]:Render(1)
    detail.purchaseButtons[1].props.onClick();Check(detailOwner.purchased==id,'actual detail purchase/free action')
    PRESSED={[KEY_RETURN]=true};Workshop.Key(detailOwner);Check(detailOwner.purchased==id,'Enter reaches same purchase path');PRESSED={}
end
local browseOwner=Owner(true,'browse');local browse=Workshop.Create(browseOwner)
local priceButton=assert(TextExists(browse,'价格'));priceButton.props.onClick()
browse=Workshop.Create(browseOwner)
Check(browseOwner.workshop.sort=='price' and browse.shopCards[1].item.id=='empty','actual price sort free-first')
Check(browse.shopCards[#browse.shopCards].item.id=='fox','actual price sort expensive-last')
Check(not TextExists(Workshop.Create(Owner(false,'browse')),'价格'),'arena does not gain purchase sort')

-- Actual purchase confirmation and transaction route, with in-memory storage
-- and prefab rows only. No file, renderer, account or native engine is invoked.
local actualPrefab=require 'construction.Prefab'
package.loaded['construction.Blueprint']={New=function() return {} end}
package.loaded['construction.Prefab']={Create=function(_,id)
    local preset=RESOURCES['Parts/Catalog.json'].presets[actualPrefab.keys[id]]
    local rows={};for _,p in ipairs(preset.parts) do rows[#rows+1]={p.type,p.pos[1],p.pos[2],p.pos[3],p.rot,p.color} end
    return {ToTable=function() return {name=preset.name,parts=rows} end}
end}
local notices={};local Host={}
function Host.Open(owner)
    local modal=Base{};modal.contentContainer_=Base{}
    function modal:AddContent(child) self.contentContainer_:AddChild(child);return self end
    owner.dialog=modal;return modal
end
function Host.Close(owner) owner.dialog=nil end
package.preload['ui.DialogHost']=function() return Host end
package.preload['ui.SourceButton']=function() return Base end
package.preload['ui.SalvagePaint']=function() return {Credit=function() end} end
local Lobby=require 'app.SalvageLobby'
local Buy=require 'ui.SalvageBuy'
local function PurchaseOwner(credits,items,fail)
    local o=Owner(true,'detail','rat');local app=o.app
    app.blueprint={ToTable=function() return {parts={}} end}
    app.bays={active=false,Slots=function() return {} end,FirstEmpty=function() return 1 end,
        CreateVehicle=function(_,id) if fail then return false,'fixture write failed' end;o.created=id;return true end}
    app.toasts={Push=function(_,message) notices[#notices+1]=message end}
    local lobby=setmetatable({app=app,data={v=1,credits=credits,items=items or {}},store={Write=function() return true end}},Lobby);app.salvageLobby=lobby
    function o.SetTab(tab,options) o.tab=tab;o.tabOptions=options end
    function o.Run(fn,success) local ok,err=fn(false);o.lastError=err;if ok and success then success() end;return ok end
    return o
end
local function FindText(widget,prefix)
    if widget.props.text and widget.props.text:sub(1,#prefix)==prefix then return widget end
    for _,c in ipairs(widget.children) do local found=FindText(c,prefix);if found then return found end end
end
local ratCost=ORACLE.prices.rat
local enough=PurchaseOwner(ratCost+1000);Check(Buy.Car(enough,'rat'),'actual confirmation opens')
local go=assert(FindText(enough.dialog.contentContainer_,'购买整车'))
Check(not go.props.disabled,'affordable actual purchase enabled');go.props.onClick()
Check(enough.created=='rat' and enough.app.salvageLobby.data.credits==1000,'purchase deducts exact original full price')
Check(enough.tab=='salvage' and enough.salvage.tab=='garage','purchase returns to actual garage tab')
Check(enough.tabOptions and enough.tabOptions.quiet,'purchase wrapper refresh is quiet after the public garage tab event')
local missingOwner=PurchaseOwner(8000);Buy.Car(missingOwner,'fox')
Check(FindText(missingOwner.dialog.contentContainer_,'购买整车').props.disabled,'actual insufficient purchase refuses debit')
local preset=RESOURCES['Parts/Catalog.json'].presets[actualPrefab.keys.rat]
local owned={};for _,p in ipairs(preset.parts) do if p.type~='core' then local key='part:'..p.type;owned[key]=(owned[key] or 0)+1 end end
local warehouse=PurchaseOwner(0,owned);Buy.Car(warehouse,'rat')
local assemble=assert(FindText(warehouse.dialog.contentContainer_,'用仓库里的零件拼'))
Check(not assemble.props.disabled,'zero-wallet owned parts alternative stays enabled');assemble.props.onClick()
Check(warehouse.created=='rat' and warehouse.app.salvageLobby.data.credits==0,'warehouse assembly creates car without double payment')
local failed=PurchaseOwner(ratCost+1000,nil,true);Buy.Car(failed,'rat');FindText(failed.dialog.contentContainer_,'购买整车').props.onClick()
Check(failed.created==nil and failed.app.salvageLobby.data.credits==ratCost+1000 and next(failed.app.salvageLobby.data.items)==nil,'failed vehicle creation refunds all purchased items/credits')
for id,cost in pairs(ORACLE.prices) do
    local buyer=PurchaseOwner(cost);Check(Buy.Car(buyer,id),'real purchase opens '..id)
    local button=assert(FindText(buyer.dialog.contentContainer_,'购买整车'))
    Check(not button.props.disabled,'exact-wallet purchase enabled '..id);button.props.onClick()
    Check(buyer.created==id and buyer.app.salvageLobby.data.credits==0,'real prefab transaction '..id)
    if cost>0 then
        local poor=PurchaseOwner(cost-1);Buy.Car(poor,id)
        Check(FindText(poor.dialog.contentContainer_,'购买整车').props.disabled,'one-credit shortage disabled '..id)
    end
end
local empty=PurchaseOwner(0);Buy.Car(empty,'empty');FindText(empty.dialog.contentContainer_,'购买整车').props.onClick()
Check(empty.created=='empty' and empty.app.salvageLobby.data.credits==0,'free chassis actual transaction succeeds at zero wallet')
''')
files = ['scripts/ui/SalvageBuy.lua', 'scripts/ui/Workshop.lua', 'scripts/ui/WorkshopCard.lua', 'scripts/ui/WorkshopButton.lua',
         'scripts/ui/WorkshopShop.lua', 'scripts/ui/WorkshopShopPaint.lua']
for file in files:
    lua.execute('assert(loadfile(...))', file)
source_files = ['shared/ui/workshop.js', 'shared/ui/salvageHub.js', 'shared/salvage/stash.js',
                'shared/css/workshop.css', 'shared/css/salvage.css', 'shared/css/new-ui-salvage.css', 'shared/salvage/items.js', 'shared/parts/defs.js']
source = ROOT / baseline['snapshot']
source_hashes = {}
for file in source_files:
    digest = hashlib.sha256((source / file).read_bytes()).hexdigest()
    assert digest == baseline['files'][file]['sha256'], f'Frozen baseline drift: {file}'
    source_hashes[file] = digest
report = {'result': 'PASS', 'checks': lua.globals().CHECKS + len(files) + len(source_files) + 2,
          'baseline': oracle['baseline'], 'prices': oracle['prices'], 'sourceHashes': source_hashes,
          'scripts': {file: hashlib.sha256((ROOT / file).read_bytes()).hexdigest() for file in files},
          'resources': {file: hashlib.sha256((ROOT / 'assets' / file).read_bytes()).hexdigest() for file in ['UI/Outgame.json', 'UI/SalvageRules.json']},
          'items': len(source_items['items']),
          'boundary': 'Frozen H5 JS vs actual Lua rules/pages/purchase callbacks; widget/render/storage APIs are substituted. Not native/Web/visual/real-account acceptance.'}
out = ROOT / 'docs/migration/evidence/workshop-shop-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'report': str(out), 'result': report['result'], 'checks': report['checks']}, ensure_ascii=False))
