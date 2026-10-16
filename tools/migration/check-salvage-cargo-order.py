"""Execute the 10/15 H5 swap method against production Lua cargo operations."""
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
const fs=require('fs'),vm=require('vm'),path=require('path'),crypto=require('crypto');
const b=JSON.parse(fs.readFileSync('docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json'));
const hashes={};function read(p){const raw=fs.readFileSync(path.join(b.snapshot,p));const h=crypto.createHash('sha256').update(raw).digest('hex');if(h!==b.files[p].sha256)throw Error('Source drift '+p);hashes[p]=h;return raw.toString();}
const loot=read('shared/salvage/salvageLoot.js'),run=read('three/src/salvage/salvageRun.js'),items=read('shared/salvage/items.js');
const data=JSON.parse(fs.readFileSync('assets/UI/Outgame.json'));
const ctx=vm.createContext({ITEMS:data.items,URLSearchParams,location:{search:''}});
const strip=s=>s.replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'');
vm.runInContext(strip(loot),ctx);
vm.runInContext(items.match(/export const SELL_RATE[^;]+;/)[0].replace('export ', '')+'\n'+items.match(/export const sellPrice[^;]+;/)[0].replace('export ',''),ctx);
vm.runInContext(strip(run)+'\nglobalThis.Run=SalvageRun;globalThis.room=roomFor;globalThis.used=slotsUsed;',ctx);
const scenarios=[];
function scenario(name,actions){const r=Object.create(ctx.Run.prototype);Object.assign(r,{cargo:new Map(),hud:{fly(){},feed(){}},drive:{player:{pos:[1,2,3]}},extras:[],time:0,_press(){},_names(){return ''},_crateMesh(){return null}});const states=[];
 for(const a of actions){let dropped=[],item=null,taken=null;if(a[0]==='take'){taken=ctx.room(r.cargo,a[1],a[2],20);if(taken>0)r.cargo.set(a[1],(r.cargo.get(a[1])||0)+taken);}else{item={id:a[1],left:a[2],state:'full'};const n=r.extras.length;r._swapIn({},item);dropped=r.extras.slice(n).flatMap(x=>x.loot);}states.push({cargo:Object.fromEntries(r.cargo),used:ctx.used(r.cargo),dropped,item,taken});}
 scenarios.push({name,actions,states});
}
for(const pair of [['part:drive3','part:hover2'],['part:hover2','part:drive3']]){
 for(const n of [1,5,6,10])scenario('tie-'+pair[0]+'-'+n,[['take',pair[0],n],['take',pair[1],n],['take','starcore',100],['swap','reactor',1],['swap','reactor',10],['take',pair[0],5],['swap','blackbox',5]]);
}
scenario('same-item-no-discard',[['take','scrap',400],['swap','scrap',1]]);
scenario('partial-stack-keeps-position',[['take','part:drive3',10],['take','part:hover2',5],['take','starcore',100],['swap','reactor',1],['take','part:drive3',1],['swap','reactor',1]]);
scenario('deleted-readded-goes-last',[['take','part:drive3',5],['take','part:hover2',5],['take','starcore',100],['swap','reactor',1],['take','part:drive3',5],['swap','blackbox',1]]);
scenario('material-drop',[['take','scrap',400],['swap','alloy',1],['swap','wire',21],['swap','starcore',5]]);
let seed=20261015;const rng=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
const ids=['part:drive3','part:hover2','scrap','alloy','reactor','starcore','blackbox','wire'];
for(let i=0;i<20;i++){const actions=[];for(let j=0;j<40;j++)actions.push([rng()<.45?'take':'swap',ids[Math.floor(rng()*ids.length)],1+Math.floor(rng()*30)]);scenario('mixed-'+i,actions);}
process.stdout.write(JSON.stringify({commit:b.commit,hashes,scenarios}));
'''

golden = json.loads(subprocess.check_output(['node', '-e', SOURCE], text=True, encoding='utf-8'))
resources = {name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8')) for name in ['UI/Outgame.json', 'Salvage/RunData.json']}

def run(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value, dict): return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list): return lua.table_from([table(v) for v in value])
        return value
    lua.globals().resources = table(resources)
    lua.execute("package.path='scripts/?.lua;'..package.path; package.loaded['core.ResourceData']={Read=function(p)return resources[p] end}")
    loot = lua.execute(code)
    lua.globals().Loot = loot
    lua.execute("package.loaded['salvage.Loot']=Loot")
    rules = lua.eval("require('salvage.RunRules')")[0]
    checks, failures = [], []
    for scenario in golden['scenarios']:
        cargo = lua.table()
        for index, (action, expected) in enumerate(zip(scenario['actions'], scenario['states'])):
            item, dropped, taken = None, [], None
            if action[0] == 'take': taken = loot.Take(cargo, action[1], action[2])
            else:
                value = table({'id': action[1], 'left': action[2], 'state': 'full'})
                result = loot.Swap(cargo, value)
                dropped = [[r[1],r[2],r[3]] for r in result.values()]
                item = dict(value.items())
            actual = {'cargo': dict(cargo.items()), 'used': loot.Used(cargo), 'dropped': dropped, 'item': item, 'taken': taken}
            name = scenario['name'] + ':' + str(index)
            if actual != expected: failures.append({'name':name,'expected':expected,'actual':actual})
            else: checks.append(name)
    # Actual full-search consumer must preserve the discarded row in its ground cache.
    for first, second in [('part:drive3','part:hover2'), ('part:hover2','part:drive3')]:
        r=rules.New(table({'loot':[], 'wrecks':[], 'extracts':[]}),table({'vaults':0}),lambda:0)
        for item_id,n in [(first,5),(second,5),('starcore',100)]: loot.Take(r.cargo,item_id,n)
        r.search=table({'o':{'g':[0,0,0]},'items':[{'id':'reactor','n':1,'left':1,'r':4,'state':'full'}], 'i':2,'done':True,'doneAt':0})
        rules.SearchStep(r,0,table({'swap':True,'pos':[1,2,3]}))
        cache=r.objects[1]
        if not cache or cache.loot[1][1] != first: failures.append({'name':'consumer-'+first,'actual':cache.loot[1][1] if cache else None})
        else: checks.append('consumer-'+first)
    gc_check=lua.execute("local seen=setmetatable({},{__mode='k'}); do local cargo={}; seen[cargo]=true; Loot.Take(cargo,'scrap',1) end; collectgarbage('collect'); collectgarbage('collect'); return next(seen)==nil")
    if gc_check: checks.append('cargo-order-does-not-retain-disposed-raid')
    else: failures.append({'name':'cargo-order-does-not-retain-disposed-raid'})
    return checks, failures

production = ROOT / 'scripts/salvage/Loot.lua'
current = production.read_text(encoding='utf-8')
checks, failures = run(current)
report = {'result':'FAIL' if failures else 'PASS','sourceCommit':golden['commit'],'sourceHashes':golden['hashes'],
          'productionHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [production,ROOT/'scripts/salvage/RunRules.lua']},
          'checks':checks,'failures':failures,'scenarios':golden['scenarios'],
          'boundary':'Actual H5 swap and Lua Take/Swap/SearchStep, Lua 5.4 via lupa. Engine/UI adapted; no GPU, live account or mobile performance acceptance.'}
out = ROOT/'docs/migration/evidence/salvage-cargo-order-offline.json'
if '--before' in sys.argv: out=ROOT/'.tmp/salvage-cargo-order-before.json'
else:
    before=subprocess.check_output(['git','show','48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/salvage/Loot.lua'])
    assert hashlib.sha256(before).hexdigest()=='4e36ee578647b25d66f84198ebbd39e471550ddd8a811b2e6a8e4d676b958d7e'
    _,negative_failures=run(before.decode('utf-8'))
    report['negativeControl']={'result':'REJECTED' if negative_failures else 'MISSED','failures':negative_failures,'productionSha256':hashlib.sha256(before).hexdigest()}
    assert negative_failures, 'Old actual implementation must fail'
    report['resourceHashes']={name:hashlib.sha256((ROOT/'assets'/name).read_bytes()).hexdigest() for name in resources}
    report['checkerSha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':len(checks),'failures':len(failures),'output':str(out)}))
if failures: sys.exit(1)
