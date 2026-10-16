"""Exercise native fixture scheduling/evidence logic without launching native GPU."""
import json
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def run(variant):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().Variant=variant
    lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local nodes,scheduled={},{}
local wall=100000;local errors={};local total=0;local done=false
Time={GetSystemTime=function()return wall end};engine={maxFps=200}
Node=function()
 local node={};nodes[#nodes+1]=node
 function node:CreateScriptObject()
  local receiver={SubscribeToEvent=function(_,_,callback)self.callback=callback end,
   HasSubscribedToEvent=function()return self.callback~=nil end}
  self.receiver=receiver;return receiver
 end
 function node:GetScriptObject()return self.receiver end
 function node:Dispose()if Variant~='stale-subscription' then self.callback=nil end end
 return node
end
V={atFrame=function(frame,callback)scheduled[frame]=callback end,
 assert=function(value,message)total=total+1;if not value then errors[#errors+1]=message end end,
 finish=function()done=true end}
function ExecuteFixture(code)
 assert(load(code))()
 for frame=1,650 do
  wall=100000+frame*1000/60
  if scheduled[frame]then scheduled[frame]()end
  for _,node in ipairs(nodes)do if node.callback and Variant~='no-listener' then node.callback()end end
  if done then break end
 end
 return total,errors,done
end
''')
    code=(ROOT/'tools/migration/check-story-mission-timers-native.lua').read_text(encoding='utf-8')
    if variant=='skip-choice-stage':code=code.replace('if not choiceChecked and elapsed>=500 then','if false then')
    total,errors,done=lua.globals().ExecuteFixture(code)
    return {'checks':total,'errors':[errors[i] for i in range(1,len(errors)+1)],'finished':done}

positive=run('normal');assert positive=={'checks':20,'errors':[],'finished':True},positive
negative={variant:run(variant) for variant in ['no-listener','stale-subscription','skip-choice-stage']}
assert all(value['errors'] for value in negative.values()),negative
print(json.dumps({'result':'PASS','fixtureLogic':positive,'negativeControls':negative,
 'boundary':'Scheduling/adapters only. No actual native Node, GPU or wall-clock acceptance.'},indent=2))
