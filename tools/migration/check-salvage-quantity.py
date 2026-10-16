"""Execute frozen H5 stepper/trade/inspect versus actual Lua widgets, no GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

SOURCE = r'''
const fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto'),path=require('node:path');
const b=JSON.parse(fs.readFileSync('docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'));
const hashes={};function read(p){const raw=fs.readFileSync(path.join(b.snapshot,p)),h=crypto.createHash('sha256').update(raw).digest('hex');if(h!==b.files[p].sha256)throw Error('Source drift '+p);hashes[p]=h;return raw.toString('utf8');}
const raw=read('shared/ui/salvageHub.js'),stash=read('shared/salvage/stash.js');read('shared/css/salvage.css');read('shared/css/new-ui-salvage.css');
const data=JSON.parse(fs.readFileSync('assets/UI/Outgame.json')),rules=JSON.parse(fs.readFileSync('assets/UI/SalvageRules.json'));
const ctx=vm.createContext({URL,ITEMS:data.items,ITEM_CATS:data.categories,RARITY:data.rarity,PARTS:{},STARTER_CARS:[],STASH_CELLS:rules.cells,REGIONS:[],PLAN_LOOT:[],PLAN_EX:[],PLAN_SPAWNS:[],OPS:[{}],OP_KEY:'op',CARGO_SLOTS:20,
icon:()=>'',partItemId:t=>'part:'+t,escapeHtml:v=>String(v),sellPrice:id=>Math.max(1,Math.floor(data.items[id].price*rules.sellRate)),stackMax:id=>rules.stack[id]||1,num:n=>n.toLocaleString('en-US'),cash:n=>String(n),sfx:{play(){}}});
const strip=r=>r.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify('file:///frozen/shared/ui/salvageHub.js'));
vm.runInContext(strip(stash)+'\nglobalThis.Stash=SalvageStash;',ctx);vm.runInContext(strip(raw)+'\nglobalThis.Hub=SalvageHub;',ctx);
const traces=[];
function scenario(name,initial,max,actions){let now=0,serial=0,timers=new Map(),listeners=new Map(),trace=[];ctx.setTimeout=(fn,ms)=>{let id=++serial;timers.set(id,{fn,at:now+ms});return id};ctx.clearTimeout=id=>timers.delete(id);ctx.addEventListener=(name,fn)=>listeners.set(name,fn);ctx.removeEventListener=name=>listeners.delete(name);
 const node=q=>({dataset:{q},handlers:{},addEventListener(name,fn){this.handlers[name]=fn},animate(){}}),minus=node('-1'),plus=node('1'),all=node('max'),inp=node(),qty=node();inp.blur=()=>inp.handlers.change();
 const box={querySelectorAll:()=>[minus,plus,all],querySelector:s=>s==='.sv-qn'?inp:qty};const h=Object.create(ctx.Hub.prototype);h.qty=initial;h._bindStepper(box,max,()=>{});
 for(const a of actions){if(a[0]==='down')(a[1]>0?plus:minus).handlers.pointerdown();else if(a[0]==='tick'){now=a[1];const ready=[...timers].filter(([,t])=>t.at<=now);for(const [id,t]of ready){timers.delete(id);t.fn()}}else if(a[0]==='up')listeners.get('pointerup')?.();else if(a[0]==='max')all.handlers.click();else if(a[0]==='wheel')inp.handlers.wheel({deltaY:a[1],preventDefault(){}});else if(a[0]==='input'){inp.value=a[1];inp.handlers.change()}trace.push(h.qty)}
 traces.push({name,initial,max,actions,trace});
}
scenario('tap',3,99,[['down',1],['up'],['tick',500]]);
scenario('hold',1,999,[['down',1],['tick',399],...Array.from({length:15},(_,i)=>['tick',400+i*70]),['up'],['tick',2000]]);
scenario('late-frame-no-burst',1,999,[['down',1],['tick',800],['tick',801],['tick',870],['up']]);
scenario('down-limit',2,3,[['down',-1],['tick',400],['up'],['max'],['down',1],['tick',800],['up']]);
for(const value of ['', 'abc', '0', '-40', '  +24abc', '12.7','2e2','0x12','999999999999999999999999999999999999','+','99'])scenario('input-'+value,3,75,[['input',value]]);
scenario('wheel',1,8,[['wheel',-1],['wheel',1],['wheel',-999],['max'],['wheel',-1]]);
const item=Object.values(data.items).find(it=>it.cat==='part'&&it.partCat==='weapon');const trades=[];
for(const [kind,n]of [['sell',1],['sell',3],['buy',1],['buy',2]]){
 const s=Object.create(ctx.Stash.prototype);Object.assign(s,{credits:99999,items:new Map([[item.id,9]]),usage:()=>({[item.id]:4}),save(){}});
 const notes=[],sounds=[];ctx.sfx.play=x=>sounds.push(x);const h=Object.create(ctx.Hub.prototype);Object.assign(h,{stash:s,qty:n,h:{toast:(text,kind)=>notes.push({text,kind})},$:()=>({animate(){}})});h._trade(kind,item,n);trades.push({kind,n,id:item.id,owned:s.owned(item.id),credits:s.credits,qty:h.qty,notes,sounds});
}
const inspect=[];for(const n of [1,3,9]){const box={style:{setProperty(){}},querySelector(){return {addEventListener(){}}}};const h=Object.create(ctx.Hub.prototype);Object.assign(h,{qty:n,stash:{count:()=>5,installed:()=>4,cellsOf:()=>Math.ceil(5/(rules.stack[item.id]||1))},_img:()=>'',_bindStepper(){}});h._inspect(box,item);inspect.push({id:item.id,initial:n,qty:h.qty,facts:[...box.innerHTML.matchAll(/<dt>(.*?)<\/dt><dd>(.*?)<\/dd>/g)].map(m=>[m[1],m[2].replace(/<[^>]*>/g,'')])});}
process.stdout.write(JSON.stringify({commit:b.commit,sourceHashes:hashes,traces,trades,inspect}));
'''
golden = json.loads(subprocess.check_output(['node', '-e', SOURCE], text=True, encoding='utf-8'))
resources = {name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8'))
             for name in ['UI/Outgame.json', 'UI/SalvageRules.json']}
paths = ['scripts/ui/SalvageQuantity.lua', 'scripts/ui/SalvagePage.lua', 'scripts/ui/SalvagePaint.lua',
         'scripts/app/SalvageLobby.lua', 'scripts/salvage/StashRules.lua']
sha = lambda name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
hashes = {name: sha(name) for name in paths}
engine_path = ROOT / '.tmp/web-engine/packed-library-cache/assets/C6eOwa2mhbjxs88K_b0TMHAJ-b8817fab.lua'
engine_source = engine_path.read_text(encoding='utf-8')
engine_wheel = engine_source[engine_source.index('function UI.HandleWheel(dx, dy)'):engine_source.index('-- Focus Management')]
# Trim the following section delimiter; execute the actual packaged handler unchanged.
engine_wheel = engine_wheel[:engine_wheel.rfind('-- ============================================================================')]
LUA = r'''
package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
local Widget={};Widget.__index=Widget
function Widget:Extend(name) local c={};c.__index=c;c.name=name;setmetatable(c,{__index=self,__call=function(t,p)local o=setmetatable({props=p or {},children={},state={cursorPos=0}},t);for _,v in ipairs(o.props.children or {}) do o:AddChild(v) end;return o end});return c end
function Widget:AddChild(v) self.children[#self.children+1]=v;v.parent=self end
function Widget:ClearChildren()self.children={} end
function Widget:Destroy()end
function Widget:SetStyle(p)for k,v in pairs(p)do self.props[k]=v end end
function Widget:SetState(p)for k,v in pairs(p)do self.state[k]=v end end
function Widget:SetDisabled(v)self.props.disabled=v end
function Widget:GetAbsoluteLayout() local p=self.props;return {x=p.left or 0,y=p.top or 0,w=p.width or 72,h=p.height or 72} end
function Widget:RenderBackgroundImage()end
function Widget:OnPointerDown()end;function Widget:OnPointerUp()end;function Widget:OnPointerCancel()end
function Widget:OnBlur()self.state.focused=false end
function Widget:OnKeyDown()end
function Widget:SetValue(v)self.props.value=v end;function Widget:GetValue()return self.props.value or '' end
function Widget:GetSelectionRange()return nil end
local Panel=Widget:Extend('Panel');local UI={Panel=Panel,ScrollView=Panel};local focus
function UI.GetFocus()return focus end;function UI.ClearFocus()if focus then local old=focus;focus=nil;old:OnBlur()end end
local pointerHit,hovered={},{};local hoverCache={[0]=hovered};local moves=0;local root={children={}}
function UI.GetScale()return 1 end;function UI.FindWidgetAt()return pointerHit end;function UI.GetHoveredWidget()return hoverCache[0]end
function UI.HandleMouseMove()moves=moves+1;hoverCache[0]=pointerHit end
local wheelEnvironment={UI=UI,enabled_=true,scale_=1,root_=root,hoveredWidgets_=hoverCache,
 Input={GetLastPosition=function()return 12,14 end},
 PointerEvent={new=function(_,p)return p end,Types={PointerMove=1},PointerTypes={Mouse=1},Buttons={None=0}},
 updateMouseHover=function()hoverCache[0]=pointerHit end,ipairs=ipairs}
assert(load(engineWheel,'@packaged-UI.HandleWheel','t',wheelEnvironment))()
local originalEngineWheel=UI.HandleWheel
package.loaded['urhox-libs/UI']=UI;package.loaded['urhox-libs/UI/Widgets/TextField']=Widget:Extend('Field')
package.loaded['ui.SalvageButton']=Panel;package.loaded['ui.SalvageItem']=Panel
package.loaded['core.ResourceData']={Read=function(p)return resources[p] end}
local text={};local D={white={},muted={},orange={},ink={},Number=function(n)local s=tostring(math.floor(n));return s:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')end,
 Begin=function()end,Rect=function()end,Line=function()end,Icon=function()end,Path=function()end,Gradient=function()end,Color=function(v)return v end,
 Width=function(_,s,size)return utf8.len(tostring(s))*size*.5 end,Text=function(_,s)table.insert(text,tostring(s))end}
package.loaded['ui.SourceDraw']=D;package.loaded['ui.VoxTheme']={Thumbnail=function()return 'thumb'end}
package.loaded['ui.SourceParagraph']={New=function()return {Draw=function()return {height=24}end}end}
package.loaded['ui.InventorySearch']=Panel
local sounds={};package.loaded['audio.UiSound']={Play=function(s)sounds[#sounds+1]=s end}
for _,name in ipairs({'nvgSave','nvgRestore','nvgIntersectScissor','nvgStrokeColor','nvgStrokeWidth','nvgStroke','nvgFillColor','nvgFill','nvgTranslate','nvgScale','nvgBeginPath','nvgArc'}) do _G[name]=function()end end
NVG_ALIGN_RIGHT=1;MOUSEB_LEFT=0;MOUSEB_RIGHT=2;KEY_RETURN=13;KEY_KP_ENTER=14;KEY_ESCAPE=27;KEY_TAB=9
local now=0;Time={GetSystemTime=function()return now end};input={focus=true,minimized=false,mousePosition={x=12,y=14},GetKeyPress=function()return false end}
if override then package.preload[override.name]=assert(load(override.source))end
local Quantity=require 'ui.SalvageQuantity';local Page=require 'ui.SalvagePage';local Paint=require 'ui.SalvagePaint';local Lobby=require 'app.SalvageLobby'
local event={pointerId=1,IsPrimaryAction=function()return true end}
for _,g in ipairs(golden.traces)do
 now=0;local owner={salvage={qty=g.initial},Track=function(v)return v end};local row=Quantity.Create(owner,function()return g.max end,0,0,388)
 local button
 for i,a in ipairs(g.actions)do
  if a[1]=='down'then button=row.children[a[2]>0 and 3 or 1];button:OnPointerDown(event)
  elseif a[1]=='tick'then now=a[2];row:Update()
  elseif a[1]=='up'then button:OnPointerUp(event);button:OnClick(event)
  elseif a[1]=='max'then row.children[4].props.onClick()
  elseif a[1]=='wheel'then pointerHit=row.field;row.field:OnWheel(0,-a[2])
  elseif a[1]=='input'then row.field:SetValue(a[2]);row.field:OnBlur()end
  Check(owner.salvage.qty==g.trace[i],'actual source stepper '..g.name..' '..i..' expected '..g.trace[i]..' got '..owner.salvage.qty)
  Check(tonumber(row.field:GetValue())==g.trace[i],'input stays synchronized '..g.name..' '..i)
 end
 Check(owner.revision==nil,'stepper never rebuilds page '..g.name)
 row:Destroy()
end
local function NewOwner(id,mode)
 local item=resources['UI/Outgame.json'].items[id];local usage={[id]=4};local notes={}
 local app={lobby='salvage',blueprint={name='车',List=function()return {{type=item.part}}end},toasts={Push=function(_,text,kind)notes[#notes+1]={text=text,kind=kind}end}}
 local lobby=setmetatable({app=app,data={credits=99999,items={[id]=9},op=1},Usage=function()return usage end,Save=function()return true end},Lobby);app.salvageLobby=lobby
 return {app=app,width=1920,height=1080,Track=function(v)return v end,salvage={tab=mode or 'market',stash=true,category='all',market='buy',qty=1,selected=id,gear={}}},notes
end
for _,g in ipairs(golden.trades)do
 local owner,notes=NewOwner(g.id);owner.salvage.market=g.kind;owner.salvage.qty=g.n;sounds={};Page.Trade(owner)
 Check(owner.app.salvageLobby:Owned(g.id)==g.owned,'actual source trade stock '..g.kind..g.n)
 Check(owner.app.salvageLobby.data.credits==g.credits,'actual source trade money '..g.kind..g.n)
 Check(owner.salvage.qty==g.qty,'actual source trade quantity resets '..g.kind..g.n)
 Check(notes[1].text==g.notes[1].text and notes[1].kind==g.notes[1].kind,'actual source trade feedback '..g.kind..g.n)
 Check(sounds[1]==g.sounds[1],'actual source trade sound '..g.kind..g.n)
end
local item=golden.trades[1].id
local function Find(root,predicate)if predicate(root)then return root end;for _,child in ipairs(root.children)do local hit=Find(child,predicate);if hit then return hit end end end
local owner,notes=NewOwner(item,'loadout');local page=Page.Create(owner)
local sell=Find(page,function(w)return w.props.text=='卖给后勤处'end);Check(sell~=nil,'actual loadout inspect exposes sell button')
local row=Find(page,function(w)return w.name=='VoxSalvageQuantityRow'end);Check(row and row.props.width==344,'actual inspect shares functional quantity row')
owner.salvage.qty=3;sell.props.onClick();Check(owner.app.salvageLobby:Owned(item)==6,'inspect sells real loose stock even market mode buy');Check(owner.salvage.qty==1,'inspect success resets quantity')
local failedOwner=NewOwner(item);failedOwner.app.salvageLobby.Save=function()return false,'disk'end;failedOwner.salvage.qty=3;failedOwner.salvage.market='sell';Page.Trade(failedOwner)
Check(failedOwner.app.salvageLobby:Owned(item)==9 and failedOwner.app.salvageLobby.data.credits==99999,'failed trade preserves assets');Check(failedOwner.salvage.qty==3,'failed trade retains quantity')
local owner=NewOwner(item);local row=Quantity.Create(owner,function()return 99 end,0,0,388)
row.children[3]:OnPointerDown(event);row.children[3]:OnPointerCancel(event);now=1000;row:Update();Check(owner.salvage.qty==2,'pointer cancellation stops hold')
row.children[3]:OnPointerDown(event);input.focus=false;row:Update();input.focus=true;now=2000;row:Update();Check(owner.salvage.qty==3,'focus loss stops hold')
row.children[3]:OnPointerDown(event);owner.dialog={};row:Update();owner.dialog=nil;now=3000;row:Update();Check(owner.salvage.qty==4,'dialog blocks hold')
focus=row.field;row.field.state.focused=true;row.field:SetValue('17');row.field:OnKeyDown(KEY_RETURN)
Check(focus==nil and owner.salvage.qty==17 and owner.salvage.quantityEnterGuard,'Enter commits and blurs quantity')
input.GetKeyPress=function(_,k)return k==KEY_RETURN end;Page.Key(owner);Check(owner.app.salvageLobby:Owned(item)==9,'Enter does not buy on commit')
input.GetKeyPress=function()return false end;Page.Key(owner);Check(owner.salvage.quantityEnterGuard==nil,'Enter guard clears after key pulse')
for _,g in ipairs(golden.inspect)do
 local owner=NewOwner(item,'loadout');owner.salvage.qty=g.initial;Page.Create(owner);Check(owner.salvage.qty==g.qty,'inspect clamps to real loose count '..g.initial)
 local surface=Paint.Surface{kind='inspect',left=0,top=0,width=400,height=802};surface.owner=owner;surface.paragraph={Draw=function()return {height=24}end};text={};surface:Render(1)
 local seen={};for _,s in ipairs(text)do seen[s]=true end
 for _,fact in ipairs(g.facts)do for _,s in ipairs(fact)do Check(seen[s],'inspect actual source fact '..s)end end
end
local owner=NewOwner(item,'loadout');local page=Page.Create(owner)
local tile=Find(page,function(w)return w.props.item and w.props.item.id==item and not w.props.compact end)
Check(tile~=nil,'stash interactive tile available');local selected=owner.salvage.selected;tile:OnPointerDown({button=MOUSEB_RIGHT})
Check(owner.app.salvageLobby:Owned(item)==8 and owner.salvage.selected==selected,'stash right click sells exactly one and preserves inspect')
tile.props.onClick();Check(owner.salvage.selected==false,'source clicking selected stash tile toggles inspect closed')
local owner=NewOwner(item);local row=Quantity.Create(owner,function()return 99 end,0,0,388);local before=owner.salvage.qty
row.children[3]:OnPointerDown({IsPrimaryAction=function()return false end});Check(owner.salvage.qty==before,'secondary pointer cannot step quantity')
row.children[3]:OnClick(nil);Check(owner.salvage.qty==before+1,'keyboard activation increments once')
row.children[3].props.disabled=true;row.children[3]:OnClick(nil);Check(owner.salvage.qty==before+1,'disabled keyboard activation rejected')
local owner=NewOwner(item);local row=Quantity.Create(owner,function()return 99 end,0,0,388);focus=row.field;row.field:SetValue('11');row.children[3]:OnPointerDown(event);row.field:SetValue('11');row:Destroy()
Check(focus==nil and row.disposed and row.hold==nil,'destroy releases focused input and held pointer')
local qty=owner.salvage.qty;now=9999;row:Update();row.children[3]:OnPointerDown(event);row.children[3]:OnClick(nil)
Check(owner.salvage.qty==qty,'late widget callbacks after destroy cannot alter quantity')
Check(Paint.Surface.OnWheel==nil,'wheel handling scoped to numeric input rather than entire deal pane')
-- Release all previous constructed-page rows before testing the complete binding lifetime.
local binding=UI.voxSalvageQuantityWheel;local remaining={};for active in pairs(binding.rows)do remaining[#remaining+1]=active end
for _,active in ipairs(remaining)do active:Destroy()end
Check(UI.HandleWheel==originalEngineWheel,'last quantity row restores actual engine wheel handler')
local owner=NewOwner(item);local row=Quantity.Create(owner,function()return 99 end,0,0,388)
local adapter=UI.HandleWheel;Check(adapter~=originalEngineWheel,'live row installs one local wheel adapter')
local owner2=NewOwner(item);local row2=Quantity.Create(owner2,function()return 99 end,0,0,388)
Check(UI.HandleWheel==adapter,'multiple rows do not stack wheel wrappers')
local outside={};pointerHit=outside;hoverCache[0]=row.field;local before=owner.salvage.qty;UI.HandleWheel(0,1)
Check(owner.salvage.qty==before and hoverCache[0]==outside,'actual packaged handler stale inner hover cannot increment outside field')
pointerHit=row.field;hoverCache[0]=outside;UI.HandleWheel(0,1)
Check(owner.salvage.qty==before+1,'actual packaged handler first outside-to-field wheel increments without lost event')
pointerHit=row2.field;hoverCache[0]=row.field;UI.HandleWheel(0,-1)
Check(owner.salvage.qty==before+1 and owner2.salvage.qty==1,'actual packaged handler routes between live fields without changing previous row')
local scrollCalls=0;local scroll={OnWheel=function(_,dx,dy)scrollCalls=scrollCalls+1;Check(dx==2 and dy==-3,'normal scroll keeps wheel deltas')end}
pointerHit=scroll;hoverCache[0]=scroll;local moveBefore=moves;UI.HandleWheel(2,-3)
Check(scrollCalls==1 and moves==moveBefore,'ordinary ScrollView path stays unchanged')
pointerHit=scroll;hoverCache[0]=row.field;UI.HandleWheel(2,-3)
Check(scrollCalls==2 and owner.salvage.qty==before+1,'leaving quantity field dispatches first wheel to the actual ScrollView')
pointerHit=outside;row.field:OnWheel(0,1);Check(owner.salvage.qty==before+1,'field rejects direct stale dispatch outside current hit')
pointerHit=row.field;row.field:OnWheel(0,0);Check(owner.salvage.qty==before+1,'zero wheel does not decrement')
row:Destroy();Check(UI.HandleWheel==adapter,'one remaining row retains shared adapter');row2:Destroy()
Check(UI.HandleWheel==originalEngineWheel and next(binding.rows)==nil,'all rows destroyed restore engine and release row references')
local owner=NewOwner(item);local row=Quantity.Create(owner,function()return 99 end,0,0,388)
local once=UI.HandleWheel;package.loaded['ui.SalvageQuantity']=nil;local Reload=require 'ui.SalvageQuantity'
local row2=Reload.Create(NewOwner(item),function()return 99 end,0,0,388)
Check(UI.HandleWheel==once,'module reentry with live row does not stack binding');row:Destroy();row2:Destroy()
Check(UI.HandleWheel==originalEngineWheel,'module reentry still restores original handler')
return checks
'''


def execute(override=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value
    lua.globals().golden = table(golden)
    lua.globals().resources = table(resources)
    lua.globals().engineWheel = engine_wheel
    if override:
        lua.globals().override = table(override)
    return list(lua.execute(LUA).values())


checks = execute()
negative = []
qty_source = (ROOT / paths[0]).read_text(encoding='utf-8')
page_source = (ROOT / paths[1]).read_text(encoding='utf-8')
variants = [
    ('noHold', 'ui.SalvageQuantity', qty_source.replace('if hold and Now()>=hold.nextAt then', 'if false then')),
    ('noAcceleration', 'ui.SalvageQuantity', qty_source.replace('(hold.ticks>12 and 5 or 1)', '1')),
    ('inputIgnored', 'ui.SalvageQuantity', qty_source.replace('self.quantityRow:SetQuantity(number==0 and 1 or number)', 'return')),
    ('wheelReversed', 'ui.SalvageQuantity', qty_source.replace('(dy>0 and 1 or -1)', '(dy>0 and -1 or 1)')),
    ('staleHoverRefreshRemoved', 'ui.SalvageQuantity', qty_source.replace('UI.HandleMouseMove(mouse.x,mouse.y)', 'do end')),
    ('inspectBuys', 'ui.SalvagePage', page_source.replace('function() M.Trade(s,true) end', 'function() M.Trade(s,false) end')),
    ('actual48efPage', 'ui.SalvagePage', subprocess.check_output(['git', 'show', '48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/ui/SalvagePage.lua']).decode('utf-8')),
]
for name, module, source in variants:
    try:
        execute({'name': module, 'source': source})
    except Exception as error:
        negative.append({'name': name, 'rejected': True, 'reason': str(error).splitlines()[0], 'sha256': hashlib.sha256(source.encode()).hexdigest()})
    else:
        raise AssertionError('Negative control passed: ' + name)
assert hashes == {name: sha(name) for name in paths}, 'Production changed while checking'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': golden['commit'], 'sourceHashes': golden['sourceHashes'],
          'packagedUi': {'path': str(engine_path.relative_to(ROOT)), 'sha256': hashlib.sha256(engine_path.read_bytes()).hexdigest(), 'handler': 'UI.HandleWheel executed unchanged'},
          'sourceCases': len(golden['traces']) + len(golden['trades']) + len(golden['inspect']),
          'productionHashes': hashes, 'resources': {'assets/' + name: sha('assets/' + name) for name in resources},
          'testInputs': {'tools/migration/check-salvage-quantity.py': sha('tools/migration/check-salvage-quantity.py')},
          'negativeControls': negative,
          'boundary': 'Actual SHA-verified frozen _bindStepper/_trade/_inspect and SalvageStash transaction code executed; actual Lua quantity pointer, timer, input, blur, wheel, cancellation, page construction, inspect sell and Lobby.Trade executed. UI/native text field host, wall clock, key polling, drawing and disk save adapted. No browser/GPU, touch keyboard, user account, full tooltip/merchant dump controls, pixel or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/salvage-quantity-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': report['sourceCases'], 'negativeControls': len(negative)}))
