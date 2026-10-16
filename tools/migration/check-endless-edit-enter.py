"""Compare run-edit Enter input with frozen H5, including submit focus clearing."""
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

reference = json.loads(subprocess.check_output(['node', '-e', r'''
const fs=require('fs'),vm=require('vm'),crypto=require('crypto');
const base=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8').replace(/^\uFEFF/,''));
const hashes={};function read(p){const b=fs.readFileSync(base.snapshot+'/'+p),h=crypto.createHash('sha256').update(b).digest('hex');
 if(h!==base.files[p].sha256)throw Error('Frozen source changed: '+p);hashes[p]=h;return b.toString();}
const edit=read('three/src/battle/endlessEdit.js'),rig=read('shared/controls/cameraRig.js');
const typing=rig.slice(rig.indexOf('export function isTyping'),rig.indexOf('export class CameraRig')).replace('export ','');
const handler=edit.slice(edit.indexOf('this.keyHandler = event => {'),edit.indexOf("window.addEventListener( 'keydown'"));
const c=vm.createContext({});vm.runInContext(typing+'\nglobalThis.make=function(e){'+handler+'return this.keyHandler;}',c);
const cases=[];for(const key of ['Enter','NumpadEnter'])for(const tag of ['CANVAS','INPUT','TEXTAREA','editable'])for(const modal of [false,true])for(const inventory of [false,true]){
 let calls=0;const owner={active:true,depart(){calls++}},e={ui:{modalOpen:modal,inventoryOpen:inventory}};
 c.make.call(owner,e)({code:key,target:{tagName:tag,isContentEditable:tag==='editable'},preventDefault(){},stopImmediatePropagation(){}});
 cases.push({key,tag,modal,inventory,departs:calls});
}
console.log(JSON.stringify({commit:base.commit,hashes,cases}));
'''], encoding='utf-8'))
production = ROOT / 'scripts/endless/Edit.lua'
code = production.read_text(encoding='utf-8')
fixture = r'''
local focus=nil;local pressed={};local held={};local calls=0;local submits=0
KEY_RETURN=1;KEY_KP_ENTER=2;KEY_ESCAPE=3
input={GetKeyPress=function(_,key)return pressed[key]or false end,GetKeyDown=function(_,key)return held[key]or false end}
package.loaded['urhox-libs/UI']={GetFocus=function()return focus end,GetRoot=function()return {}end}
for _,id in ipairs({'construction.Blueprint','endless.Inventory','Config','core.Coord'})do package.loaded[id]={}end
package.loaded['ui.EndlessEditBar']={Attach=function()return {Update=function()end}end}
local Edit=assert(load(CODE,'@scripts/endless/Edit.lua'))()
local noop=function()end
local build={hud={root={},playfield={},buttons={},stats={pane={tiers={}}}},controls={Cancel=noop},buildCamera={Release=noop},Update=noop}
local e=Edit.New({});e.build=build;e.hudRoot=build.hud.root;e.StockCards=noop;e.Depart=function()calls=calls+1 end
local checks,failures=0,{}
local function Check(ok,label)checks=checks+1;if not ok then failures[#failures+1]=label end end
for _,case in ipairs(CASES)do
 for _,mode in ipairs({'event','poll'})do
  calls=0;pressed={};held={};e.departKeyConsumed=false
  focus=case.tag=='CANVAS'and build.hud.playfield or {OnTextInput=noop}
  build.dialog=case.modal and {}or nil;build.inventoryPanel=case.inventory and {}or nil
  local key=case.key=='Enter'and KEY_RETURN or KEY_KP_ENTER
  if mode=='event'then e:HandleKey(key)else pressed[key]=true;e:Update(.016)end
  Check(calls==case.departs,mode..':'..case.key..':'..case.tag..':'..tostring(case.modal)..':'..tostring(case.inventory))
 end
end
build.dialog=nil;build.inventoryPanel=nil;focus=nil
for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER})do
 calls=0;pressed={};held={};e.departKeyConsumed=false
 local name={props={onSubmit=function(field,value)submits=submits+1;focus=nil;return value end}}
 build.hud.name=name;e:ConfigureHud();e:ConfigureHud()
 pressed[key]=true;held[key]=true
 Check(name.props.onSubmit(name,'renamed')=='renamed','name submit return preserved '..key)
 Check(submits==key,'one original name submit callback '..key)
 e:HandleKey(key);e:Update(.016)
 Check(calls==0,'same submit press cannot depart after ClearFocus '..key)
 pressed={};e:Update(.016);e:HandleKey(key)
 Check(calls==0,'held submit cannot depart '..key)
 held={};e:Update(.016);pressed[key]=true;held[key]=true;e:Update(.016)
 Check(calls==1,'new press after release departs '..key)
end
for _,key in ipairs({KEY_RETURN,KEY_KP_ENTER})do
 calls=0;e.departKeyConsumed=false;pressed={[key]=true};held={[key]=true};e.shop={Close=noop};e:HandleKey(key);e:Update(.016)
 Check(calls==0,'shop keeps ownership '..key);e.shop=nil
end
return {checks=checks,failures=failures}
'''


def run(candidate):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().CODE = candidate
    lua.globals().CASES = lua.table_from([lua.table_from(c) for c in reference['cases']])
    result = lua.execute(fixture)
    return {'checks': result['checks'], 'failures': list(result['failures'].values())}


result = run(code)
assert not result['failures'], result
mutations = {
    'missing typing guard': code.replace('return not (focus and focus.OnTextInput and focus~=self.build.hud.playfield)', 'return true'),
    'submit focus clear leaks': code.replace('self.departKeyConsumed=true', 'self.departKeyConsumed=false'),
    'missing keypad Enter': code.replace('or key==KEY_KP_ENTER', '').replace('or input:GetKeyPress(KEY_KP_ENTER)', ''),
}
negative = {name: run(candidate) for name, candidate in mutations.items()}
assert all(item['failures'] for item in negative.values()), negative
report = {'result': 'PASS', 'checks': result['checks'], 'sourceCommit': reference['commit'],
          'sourceHashes': reference['hashes'], 'productionHashes': {'scripts/endless/Edit.lua': hashlib.sha256(production.read_bytes()).hexdigest()},
          'negativeControls': negative,
          'boundary': 'Actual frozen JS key handler/isTyping and production Lua methods. UI/native dependencies stubbed; no browser, rendering, account or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/endless-edit-enter-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': result['checks'], 'negativeControls': len(negative), 'evidence': str(out)}))
