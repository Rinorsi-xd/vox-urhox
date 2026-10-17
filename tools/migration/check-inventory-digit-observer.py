"""Exercise the real QA observer across Update/PostUpdate input boundaries."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

observer = ROOT / 'tools/migration/inventory-digit-stock-observer.lua'
source = observer.read_text(encoding='utf-8')


def exercise(code):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
messages={};calls={update=0,post=0};pressed=false;KEY_F8=123
package.loaded['urhox-libs/UI']={GetViewportSize=function() return 1280,720 end}
package.loaded['parts.Defs']={}
cjson={encode=function(v)
 assert(v.width==1280 and v.height==720 and v.build==false and v.inventory==false)
 return '{"width":1280,"height":720,"build":false,"inventory":false}'
end}
print=function(s) messages[#messages+1]=s end
input={GetKeyPress=function(_,key) assert(key==KEY_F8);return pressed end}
HandleUpdate=function() calls.update=calls.update+1;pressed=false end
HandlePostUpdate=function() calls.post=calls.post+1 end
''')
    lua.execute(code)
    lua.execute('''
HandleUpdate();HandlePostUpdate()
assert(#messages==1 and messages[1]=='INVENTORY_DIGIT_OBSERVER_READY')
pressed=true;HandleUpdate();HandlePostUpdate()
HandleUpdate();HandlePostUpdate()
pressed=true;HandleUpdate();HandlePostUpdate()
HandlePostUpdate()
assert(calls.update==4 and calls.post==5)
assert(VOX_HANGAR==nil and VOX_TRIAL==nil)
''')
    messages = list(lua.globals().messages.values())
    states = [json.loads(s.removeprefix('INVENTORY_DIGIT_STATE '))
              for s in messages if s.startswith('INVENTORY_DIGIT_STATE ')]
    return len(states) == 2 and len(messages) == 3


assert exercise(source), 'Observer lost or repeated a latched snapshot'
old = source.replace("if input:GetKeyPress(KEY_F8) then pending=true end", '')
old = old.replace('if pending then', 'if input:GetKeyPress(KEY_F8) then')
assert not exercise(old), 'Negative control did not reject PostUpdate-only input'
result = {
    'result': 'PASS',
    'observerSha256': hashlib.sha256(observer.read_bytes()).hexdigest(),
    'checks': ['initial ready', 'two update-phase requests yield two snapshots',
               'idle post does not repeat snapshot', 'original callbacks retained',
               'no game-state creation', 'post-only negative control rejected'],
    'boundary': 'Lua 5.4 phase adapter; actual Web rerun remains required',
}
if len(sys.argv) > 1:
    (ROOT / sys.argv[1]).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
