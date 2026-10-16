"""Offline check of actual MVP skip state and production rematch name contracts."""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value

arena = json.loads((root / 'assets/Combat/Arena.json').read_text(encoding='utf-8'))
lua.globals().arena = convert(arena)
count = lua.execute('''
package.path='scripts/?.lua;'..package.path
package.loaded['render.MvpStage']={}
package.loaded['combat.ArenaData']=arena
local Show=require 'app.MvpShow'
local Matchmaker=require 'combat.Matchmaker'
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
local show=setmetatable({t=0,stage={S=4,height=3},preparing=true},Show)
show:Skip();Check(show.t==0 and show.finishing==nil,'Preparing ignores Space')
show.preparing=false;show:Skip();Check(show.t==7.1 and show.jumped and show.finishing==nil,'First Space jumps to title')
show:Skip();Check(show.finishing==0 and not show.done,'Second Space begins fade at zero')
show.music={Update=function() end};show.session={HasFocus=function() return true end};show.Dispose=function(self) self.disposed=true end
show:Update(.36);Check(show.done and show.disposed,'Actual Update completes .36 second fade and disposal')
show.finishing=nil;show:Skip();Check(show.finishing==nil,'Done ignores Space')
for size=3,4 do
    for seed=1,500 do
        local stored
        local store={Read=function() return stored end,Write=function(_,_,value) stored=value;return true end}
        local first=Matchmaker.Find(store,size,1,'player',seed)
        local second=Matchmaker.Find(store,size,1,'player',seed)
        local old,names={},{}
        for _,team in ipairs({'blue','red'}) do for _,member in ipairs(first[team]) do if member.bot then old[member.name]=true end end end
        local count=0
        for _,team in ipairs({'blue','red'}) do for _,member in ipairs(second[team]) do if member.bot then
            Check(not old[member.name],'Previous names filtered even with same seed')
            Check(not names[member.name],'Current roster names unique');names[member.name]=true;count=count+1
        end end end
        Check(count==size*2-1,'Roster has configured bot count')
    end
end
return checks
''')
paths = ['scripts/app/MvpShow.lua', 'scripts/combat/MvpMotion.lua', 'scripts/combat/Matchmaker.lua',
         'scripts/combat/MatchActions.lua', 'scripts/app/LoadingFlow.lua', 'scripts/app/HangarApp.lua',
         'scripts/app/TrialSession.lua', 'scripts/ui/MatchHud.lua']
report = {'result': 'PASS', 'checks': count, 'runtime': lua.lua_implementation,
          'productionHashes': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths},
          'boundary': 'Actual MVP Skip and terminal Update using stage/music/session stubs; actual Matchmaker.Find over 1000 two-match fixtures with successful in-memory storage and real Arena names. No browser, GPU, queue runtime or visual acceptance.'}
out = root / 'docs/migration/evidence/combat-result-production-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': count, 'evidence': str(out)}))
