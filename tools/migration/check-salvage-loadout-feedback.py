"""Frozen H5 loadout/tile output versus actual Lua page construction and drawing."""
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
const hashes={};function read(p){const r=fs.readFileSync(path.join(b.snapshot,p)),h=crypto.createHash('sha256').update(r).digest('hex');if(h!==b.files[p].sha256)throw Error('Source drift '+p);hashes[p]=h;return r.toString('utf8');}
const raw=read('shared/ui/salvageHub.js'),stash=read('shared/salvage/stash.js');
const css=read('shared/css/salvage.css')+read('shared/css/new-ui-salvage.css'),style=read('shared/css/style.css');
if(!css.includes('body #salvage .sv-tile.bad { box-shadow: inset 0 0 0 2px var(--bad); }')||!style.includes('--bad: #ff3b30;'))throw Error('CSS marker drift');
const d=JSON.parse(fs.readFileSync('assets/UI/Outgame.json'));const PARTS={};for(const it of Object.values(d.items))if(it.part)PARTS[it.part]={cat:it.partCat,hp:1};
const ctx=vm.createContext({URL,ITEMS:d.items,ITEM_CATS:d.categories,RARITY:d.rarity,PARTS,STARTER_CARS:[{source:{parts:[]}}],STASH_CELLS:120,REGIONS:[],PLAN_LOOT:[],PLAN_EX:[],PLAN_SPAWNS:[],OPS:[{}],OP_KEY:'op',CARGO_SLOTS:20,
icon:()=>'',partItemId:t=>'part:'+t,escapeHtml:v=>String(v),sellPrice:id=>Math.max(1,Math.floor(d.items[id].price*.6)),savedOp:()=>({name:'巡逻'}),data:d});
const strip=r=>r.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'').replaceAll('import.meta.url',JSON.stringify('file:///frozen/shared/ui/salvageHub.js'));
vm.runInContext(strip(stash)+'\nglobalThis.Stash=SalvageStash;',ctx);
vm.runInContext(strip(raw)+'\nglobalThis.Hub=SalvageHub;',ctx);
const output=vm.runInContext(`(()=>{
const bycat=c=>Object.values(data.items).find(it=>it.cat==='part'&&it.partCat===c),weapon=bycat('weapon'),move=bycat('movement'),fn=bycat('function'),gear=Object.values(data.items).filter(it=>it.cat==='gear');
const cases=[];for(const kind of ['normal','short','other-bay-short','removed-gear','no-function','many-function']){
 const specs=[[weapon.part,2],[move.part,4],...(kind==='no-function'?[]:[[fn.part,kind==='many-function'?7:1]])];
 const parts=specs.flatMap(([type,n])=>Array.from({length:n},()=>({type})));const need=partsNeeded({parts:new Map(parts.map((p,i)=>[i,p]))});
 const owned={...need,[gear[0].id]:3,[gear[1].id]:0},usage={...need};
 if(kind==='short')owned[weapon.id]=1;if(kind==='other-bay-short')usage[move.id]+=5;
 if(kind==='removed-gear')usage[gear[0].id]=3;
 const s=Object.create(Stash.prototype);Object.assign(s,{credits:1000,items:new Map(Object.entries(owned)),usage:()=>usage});
 const nodes={};const node=k=>nodes[k]??(nodes[k]={dataset:{},innerHTML:'',textContent:''});
 const h=Object.create(Hub.prototype);Object.assign(h,{root:{querySelectorAll:()=>[]},car:{name:'车',parts:new Map(parts.map((p,i)=>[i,p]))},diag:{stats:{topSpeed:10}},stash:s,
 gear:[gear[0].id,gear[1].id],tab:'loadout',h:{},$:(k)=>node(k),renderStash(){},_tip(){return '';},_img(){return '';}});
 const tiles=[];h._tile=function(it,p){const html=Hub.prototype._tile.call(this,it,p);tiles.push({id:it.id,count:p.n,bad:p.cls==='bad',gear:!!p.attr?.includes('data-gid'),label:html.match(/<b class="sv-tn">([^<]+)/)?.[1]??null});return html;};h.render();
 cases.push({kind,parts:parts.map(p=>p.type),owned,usage,gearInput:[gear[0].id,gear[1].id],gear:h.gear,tiles,emptySlots:(node('.sv-sections').innerHTML.match(/class="sv-slot"/g)||[]).length,disabled:node('[data-sv="deploy"]').disabled});
}
const counts=[null,0,1,2,999,9999,10000,10500,11500,12500,13500,14500,15500,99999,100000,9999999,9007199254740991];
for(let n=10000;n<20000;n+=50)counts.push(n);
const tiles=counts.map(n=>{const html=Hub.prototype._tile.call({_tip:()=>'',_img:()=>''},weapon,{n});return {n,label:html.match(/<b class="sv-tn">([^<]+)/)?.[1]??null};});
return {cases,tiles};})()`,ctx);
process.stdout.write(JSON.stringify({commit:b.commit,sourceHashes:hashes,...output}));
'''
golden = json.loads(subprocess.check_output(['node', '-e', SOURCE], text=True, encoding='utf-8'))
paths = ['scripts/ui/SalvagePage.lua', 'scripts/ui/SalvageItem.lua', 'scripts/salvage/StashRules.lua']
hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
resources = {p: json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8')) for p in ['UI/Outgame.json', 'UI/SalvageRules.json']}
FIXTURE = r'''
package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,label) assert(ok,label);checks[#checks+1]=label end
package.loaded['core.ResourceData']={Read=function(p) return resources[p] end}
local Widget={};Widget.__index=Widget
function Widget:Extend() local c={};c.__index=c;setmetatable(c,{__index=self,__call=function(t,p) local o=setmetatable({props=p or {},children={},state={}},t);for _,v in ipairs(o.props.children or {}) do o:AddChild(v) end;return o end});return c end
function Widget:AddChild(v) self.children[#self.children+1]=v;v.parent=self end
function Widget:ClearChildren() self.children={} end
function Widget:Destroy() end
function Widget:SetStyle(p) for k,v in pairs(p) do self.props[k]=v end end
function Widget:GetAbsoluteLayout() local p=self.props;return {x=p.left or 0,y=p.top or 0,w=p.width or 72,h=p.height or 72} end
function Widget:RenderBackgroundImage() end
local Panel=Widget:Extend();package.loaded['urhox-libs/UI']={Panel=Panel,ScrollView=Panel}
package.loaded['ui.ActionButton']=Widget:Extend();package.loaded['ui.SalvageButton']=Panel
local text,rects={},{};local D={white={255,255,255,255},muted={},orange={},Begin=function() end,Number=tostring,Icon=function() end,Line=function() end,
 Width=function(_,s,size) return #s*size*.25 end,Text=function(_,s,x,y,size,c,font,align) text[#text+1]={text=s,x=x,y=y,size=size,color=c,font=font,align=align} end,
 Rect=function(_,x,y,w,h,c) rects[#rects+1]={x=x,y=y,w=w,h=h,color=c} end}
package.loaded['ui.SourceDraw']=D;package.loaded['ui.SourceRelief']={Halftone=function() end};package.loaded['ui.VoxTheme']={Thumbnail=function() return 'thumb' end}
package.loaded['ui.SourceParagraph']={New=function() return {} end}
package.loaded['ui.SalvagePaint']={Page=Panel,Surface=Panel,Text=Panel,Value=function() return 1 end}
package.loaded['ui.InventorySearch']=Panel
NVG_ALIGN_RIGHT=1;MOUSEB_RIGHT=2
if override then package.preload[override.name]=assert(load(override.source)) end
local Item=require 'ui.SalvageItem';local Page=require 'ui.SalvagePage';local Stash=require 'salvage.StashRules';local data=resources['UI/Outgame.json']
local first;for _,it in pairs(data.items) do if it.cat=='part' and it.partCat=='weapon' then first=it;break end end
for i,g in ipairs(golden.tiles) do
 for _,compact in ipairs({true,false}) do
  text={};rects={};local tile=Item{item=first,count=g.n,compact=compact,width=compact and 72 or 84,height=compact and 72 or 84};tile:Render(1)
  local label;for _,t in ipairs(text) do if t.font=='vox-tabular' then label=t.text;Check(t.size==(compact and 15 or 17),'source count size '..i) end end
  Check(label==g.label,'actual source count label '..i..' '..tostring(g.n)..' expected '..tostring(g.label)..' got '..tostring(label))
 end
end
for _,bad in ipairs({true,false}) do rects={};local tile=Item{item=first,bad=bad,width=72,height=72};tile:Render(1);local borders={}
 for _,r in ipairs(rects) do local c=r.color;if c[1]==255 and c[2]==59 and c[3]==48 then borders[#borders+1]=r end end
 Check(#borders==(bad and 4 or 0),'source red frame controlled by shortage '..tostring(bad))
 for _,r in ipairs(borders) do Check((r.w==2 or r.h==2) and r.x>=0 and r.y>=0 and r.x+r.w<=72 and r.y+r.h<=72,'source2px inset red marker') end
end
for _,g in ipairs(golden.cases) do
 local parts={};for i,id in ipairs(g.parts) do parts[i]={type=id} end
 local app={blueprint={name='车',List=function() return parts end},toasts={Push=function() end},previews={}}
 local lobby={data={items=g.owned,credits=1000,op=1},Usage=function() return g.usage end,Shortfall=function() return Stash.Shortfall(g.owned,g.usage) end,
 Loose=function(_,id) return math.max(0,(g.owned[id] or 0)-(g.usage[id] or 0)) end,Owned=function(_,id) return g.owned[id] or 0 end}
 app.salvageLobby=lobby
 local s={app=app,width=1920,height=1080,Track=function(v) return v end,salvage={tab='loadout',gear=g.gearInput,gearPop=true}}
 local page=Page.Create(s);local actual,empty,cta={},0
 local function Walk(w) local p=w.props
  if p.item and p.compact then actual[p.item.id]={count=p.count,bad=p.bad or false} end
  if p.kind=='slot' and w.parent~=page then empty=empty+1 end
  if p.text=='出发' then cta=w end
  for _,v in ipairs(w.children) do Walk(v) end
 end;Walk(page)
 Check(cta.props.disabled==g.disabled,'source global shortfall controls CTA '..g.kind)
 local actualGear={};for _,id in ipairs(s.salvage.gear) do actualGear[#actualGear+1]=id end
 Check(#actualGear==#g.gear,'source removes unavailable carried gear '..g.kind)
 for i,id in ipairs(g.gear) do Check(actualGear[i]==id,'source retained gear order '..g.kind) end
 for _,tile in ipairs(g.tiles) do local t=actual[tile.id];Check(t and t.count==tile.count,'actual page source installed/loose quantity '..g.kind..' '..tile.id)
  Check(t.bad==tile.bad,'actual page uses full warehouse shortage '..g.kind..' '..tile.id) end
 local gearSlots=4-#g.gear;Check(empty==g.emptySlots+gearSlots,'source category placeholder minimum '..g.kind..' '..empty)
 for _,w in ipairs(page.children) do local p=w.props;if p.kind=='gear' then
  local it;for _,v in pairs(data.items) do if v.name==p.text then it=v end end
  if it then local n=lobby:Loose(it.id);Check(p.disabled==(n<1),'source popup uses loose count '..g.kind..' '..it.id)
   Check(p.subtitle==(n>0 and ('仓库里 '..n..' 个 · '..it.desc) or '仓库里没有，去商人那里买'),'source popup exact quantity feedback '..g.kind..' '..it.id) end
 end end
end
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
    if override:
        lua.globals().override = table(override)
    return list(lua.execute(FIXTURE).values())


checks = execute()
negative = []
item_path = 'scripts/ui/SalvageItem.lua'
old = subprocess.check_output(['git', 'show', '48ef15f2c9c95c400f91ee6e34309399d02b3733:' + item_path]).decode('utf-8')
variants = [('actual48efItem', 'ui.SalvageItem', old),
            ('noShortageMarker', 'ui.SalvageItem', (ROOT / item_path).read_text(encoding='utf-8').replace('if self.props.bad then', 'if false then')),
            ('noPageShortage', 'ui.SalvagePage', (ROOT / paths[0]).read_text(encoding='utf-8').replace('bad=(short[it.id] or 0)>0', 'bad=false')),
            ('wrongOwnedGear', 'ui.SalvagePage', (ROOT / paths[0]).read_text(encoding='utf-8').replace('local loose=sv.loose[it.id] or 0;', 'local loose=lobby:Owned(it.id);'))]
for name, module, source in variants:
    try:
        execute({'name': module, 'source': source})
    except Exception as error:
        negative.append({'name': name, 'rejected': True, 'reason': str(error).splitlines()[0], 'sha256': hashlib.sha256(source.encode()).hexdigest()})
    else:
        raise AssertionError('Negative control passed: ' + name)
assert hashes == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}, 'Production drift'
report = {'result': 'PASS', 'checks': checks, 'sourceCommit': golden['commit'], 'sourceHashes': golden['sourceHashes'],
          'sourceCases': len(golden['cases']) + len(golden['tiles']), 'productionHashes': hashes,
          'resources': {'assets/' + p: hashlib.sha256((ROOT / 'assets' / p).read_bytes()).hexdigest() for p in resources},
          'testInputs': {'tools/migration/check-salvage-loadout-feedback.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
          'negativeControls': negative, 'boundary': 'Actual frozen SalvageHub.render/renderLoadout/_tile and SalvageStash.count/shortfall executed; imported item/part taxonomy supplied from current exported data. Actual Lua page construction, StashRules and Item.Render executed, UI/native drawing host adapted. No browser/GPU, user old account, rich tooltip, full merchant quantity input or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/salvage-loadout-feedback-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'sourceCases': report['sourceCases'], 'negativeControls': len(negative)}))
