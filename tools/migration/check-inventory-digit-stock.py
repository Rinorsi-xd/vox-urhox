"""Compare the actual frozen H5 digit method with the Lua inventory consumer."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

oracle = r'''
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const raw=fs.readFileSync(path.join(baseline.snapshot,'shared/ui/inventory.js'),'utf8');
const sha=crypto.createHash('sha256').update(raw).digest('hex');
if(sha!==baseline.files['shared/ui/inventory.js'].sha256)throw Error('Frozen source drift');
const source=raw.replace(/\r\n/g,'\n');
function method(name){const start=source.indexOf('\t'+name+'('),end=source.indexOf('\n\t}\n',start);if(start<0||end<0)throw Error(name);return source.slice(start,end+4);}
const context=vm.createContext({document:{activeElement:null},icon:()=>'',el:()=>({dataset:{},style:{},classList:{toggle(){}},setAttribute(){},appendChild(){},addEventListener(){}})});
vm.runInContext('globalThis.Model=class{'+method('_available')+method('digit')+method('_fill')+'}',context);
const cases=[];
for(const mode of ['normal','salvage','endless'])for(const count of [0,1,4])for(const focus of [false,true])for(const target of [false,'laser1']){
 const calls=[],owner=new context.Model();owner.hoverType=target;
 owner.runInventory=mode==='normal'?null:{remaining:()=>count};
 owner.h={onAssign:(slot,id)=>calls.push(['assign',slot,id]),onSelectSlot:slot=>calls.push(['select',slot])};
 owner.digit(3);cases.push({mode,count,focus,target,calls});
}
const tabCases=[];
for(const mode of ['normal','salvage','endless'])for(const count of [0,1,4]){
 const owner=new context.Model(),defs=[{id:'laser1',name:'laser',budget:1},{id:'mg1',name:'mg',budget:1}];
 owner.runInventory=mode==='normal'?null:{remaining:id=>id==='laser1'?count:1,...(mode==='salvage'?{onUnavailable(){}}:{})};
 owner.hotbar=['laser1'];owner.active=0;owner.thumbs={};owner.query='laser';owner.cats={children:[]};owner.count={};
 owner.grid={children:[],contains:()=>false,appendChild(b){this.children.push(b)}};owner._list=()=>defs;
 owner._fill();const allowed=owner.grid.children.filter(b=>!b.disabled).map(b=>b.dataset.type);
 tabCases.push({mode,count,allowed,initial:allowed.includes('laser1')?'laser1':'close'});
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceSha256:sha,cases,tabCases}));
'''
golden = json.loads(subprocess.check_output(['node', '-e', oracle], cwd=ROOT, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local Widget={};function Widget:Extend() return self end
FOCUS=false
package.loaded['urhox-libs/UI']={Panel=Widget,GetFocus=function() return FOCUS end,SetFocus=function(widget) FOCUS=widget end}
for _,name in ipairs({'audio.UiSound','urhox-libs/UI/Core/Input','ui.InventorySearch',
 'ui.InventoryList','ui.InventoryDetail','ui.InventoryDetailScroll','ui.BuildHotbar',
 'render.SceneBackdrop','controls.TouchMode','ui.InventoryCardMotion',
 'ui.InventoryShadows','ui.VoxTheme','ui.SourceDraw','parts.Defs','construction.Inventory',
 'ui.InventoryChrome'}) do package.loaded[name]={} end
PANEL=require 'ui.InventoryPanel'
KEYS=require 'ui.InventoryKeys'
function Run(mode,count,focus,target)
 local calls={};local owner=setmetatable({hotbar={Refresh=function() end}},PANEL)
 owner.session={AssignHotbar=function(_,slot,id) calls[#calls+1]={'assign',slot,id} end,
  SelectHotbar=function(_,slot) calls[#calls+1]={'select',slot} end}
 if mode=='salvage' then owner.stockRemaining={laser1=count} end
 if mode=='endless' then owner.Unavailable=function() return count<=0 end end
 owner.hoverType=target
 FOCUS=focus and target and {inventoryOwner=owner,props={partType=target}} or false
 owner:Digit(4)
 return calls
end
function Stops(mode,count)
 local close={node=true,props={id='close'}}
 local owner=setmetatable({search={node=true,props={}},closeButton=close,categoryBar={children={}},
  materialBar={IsVisible=function() return false end},detail={},hotbar={slots={}},
  footer={children={{children={{}}}}},results={{id='laser1'},{id='mg1'}},
  list={scrollOffset_=0,props={topInset=16},rowHeight_=100,ScrollToIndex=function() end,
   UpdateVisibleItems=function() end,pool_={inUse={}}},columns=1,itemHeight=90,centerHeight=400},PANEL)
 for i,id in ipairs({'laser1','mg1'}) do owner.list.pool_.inUse[i]={cells={{type=id,root={node=true,props={partType=id}}}}} end
 owner.Detail=function() end
 if mode=='salvage' then owner.stockRemaining={laser1=count,mg1=1} end
 if mode=='endless' then owner.Unavailable=function(_,id) return id=='laser1' and count<=0 end end
 local allowed={};for _,stop in ipairs(KEYS.Stops(owner)) do if stop.part then allowed[#allowed+1]=stop.part end end
 local focused=KEYS.Focus(owner,{part='laser1',index=1})
 if not focused then assert(KEYS.Focus(owner,{widget=close})) end
 return allowed,FOCUS.props.partType or FOCUS.props.id
end
''')
failures = []
for case in golden['cases']:
    actual = lua.globals().Run(case['mode'], case['count'], case['focus'], case['target'])
    calls = [list(item.values()) for item in actual.values()]
    # The source uses zero-based slots; the Lua hotbar uses one-based slots.
    expected = [[row[0], row[1] + 1, *row[2:]] for row in case['calls']]
    if calls != expected:
        failures.append({'case': case, 'actual': calls, 'expected': expected})

for case in golden['tabCases']:
    allowed, initial = lua.globals().Stops(case['mode'],case['count'])
    actual = list(allowed.values())
    if actual != case['allowed'] or initial != case['initial']:
        failures.append({'case': case, 'actual': {'allowed':actual,'initial':initial}})

negative_controls=[]
identity=json.loads((ROOT/'.tmp/outgame-cached-1792213080660/identity.json').read_text(encoding='utf-8'))
old_path=ROOT/'.tmp/outgame-cached-1792213080660/scripts/ui/InventoryKeys.lua'
old=old_path.read_bytes()
assert hashlib.sha256(old).hexdigest()==identity['identity']['scripts']['ui/InventoryKeys.lua']
current_keys=lua.globals().KEYS
lua.globals().KEYS=lua.execute(old.decode('utf-8'))
allowed,initial=lua.globals().Stops('endless',0)
assert 'laser1' in list(allowed.values()) and initial=='laser1'
negative_controls.append('Frozen c074 keys incorrectly focus exhausted endless part')
keys_text=(ROOT/'scripts/ui/InventoryKeys.lua').read_text(encoding='utf-8')
mutant=keys_text.replace('owner.stockRemaining~=nil or not owner:Unavailable(id)','not owner:Unavailable(id)')
assert mutant!=keys_text
lua.globals().KEYS=lua.execute(mutant)
allowed,initial=lua.globals().Stops('salvage',0)
assert 'laser1' not in list(allowed.values()) and initial=='close'
negative_controls.append('Incorrect buyable filtering rejected for zero-stock salvage')
lua.globals().KEYS=current_keys

report = {'result': 'FAIL' if failures else 'PASS', 'cases': len(golden['cases']), 'tabCases':len(golden['tabCases']),
          'failures': failures, 'baseline': golden['baseline'],
          'sourceSha256': golden['sourceSha256'],
          'productionSha256': hashlib.sha256((ROOT/'scripts/ui/InventoryPanel.lua').read_bytes()).hexdigest(),
          'keysSha256': hashlib.sha256((ROOT/'scripts/ui/InventoryKeys.lua').read_bytes()).hexdigest(),
          'negativeControls':negative_controls,
          'boundary': 'Actual frozen H5 _fill/_available/digit and real Lua InventoryPanel:Digit/Remaining/Unavailable plus InventoryKeys.Stops/Focus. Callback/DOM/focus/layout adapters; source disabled-button focusability mapped to stops, no browser, complete inventory or performance acceptance.'}
output = Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'docs/migration/evidence/inventory-digit-stock-offline.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'cases': report['cases'], 'failures': len(failures), 'output': str(output)}))
sys.exit(bool(failures))
