"""Bound exact sampled-cell cache ownership in a real Lua 5.4 VM (no native claims)."""
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/lifecycle-python'))
from lupa.lua54 import LuaRuntime


def measure(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    null = lua.table()

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({k: convert(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(v) for v in value])
        return null if value is None else value

    lua.globals().read_resource = lambda p: convert(json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8-sig')))
    lua.globals().cjson = lua.table(null=null)
    lua.globals().turret_path = path.as_posix()
    lua.execute("package.path='scripts/?.lua;scripts/?/init.lua;'..package.path;package.preload['core.ResourceData']=function() return {Read=function(p) return read_resource(p) end} end;package.preload['construction.TurretRange']=function() return assert(loadfile(turret_path))() end")
    text = lua.execute("""
local BP,Prefab,Turret=require('construction.Blueprint'),require('construction.Prefab'),require('construction.TurretRange')
local cache
for i=1,30 do local name,value=debug.getupvalue(Turret.For,i);if not name then break end;if name=='cached' then cache=value end end
assert(cache and getmetatable(cache).__mode=='k','cache must own blueprints weakly')
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function Memory() collectgarbage('collect');return collectgarbage('count') end
local rows={}
for _,name in ipairs({'raceCar','megaMech'}) do
    local bp=Prefab.Create(BP.New(),name);local before=Memory()
    local result=Turret.For(bp);local initial=Memory()
    for step=1,3 do
        local list=bp:List()
        for i=#list,1,-1 do if list[i].type~='core' then bp:Remove(list[i].id);break end end
        result=Turret.For(bp)
    end
    local after=Memory();local cells,rays,seen=0,0,0
    for _,entry in pairs(cache[bp].entries) do
        if entry.context then for _,row in pairs(entry.context.rays or {}) do for _,ray in pairs(row) do
            rays=rays+1
            if type(ray)=='string' then cells=cells+#ray/8
            else cells=cells+#ray.cells;seen=seen+Count(ray.seen or {}) end
        end end end
    end
    local row={name=name,initialKiB=initial-before,afterThreeRemovalsKiB=after-before,cells=cells,rays=rays,pendingSeenCells=seen}
    assert(after-before<16384,'sample cache for one fixture must stay below 16 MiB')
    bp=nil;result=nil;Memory();row.remainingWeakEntries=Count(cache)
    assert(row.remainingWeakEntries==0,'dropping blueprint must release every cached ray')
    rows[#rows+1]=row
end
local function Esc(s) return string.format('%q',s) end
local out={}
for _,row in ipairs(rows) do
    local fields={};for k,v in pairs(row) do fields[#fields+1]=Esc(k)..':'..(type(v)=='string' and Esc(v) or tostring(v)) end
    out[#out+1]='{'..table.concat(fields,',')..'}'
end
return '['..table.concat(out,',')..']'
""")
    return json.loads(text)


candidate = ROOT / '.tmp/TurretRange-sample-cache-candidate.lua'
production = ROOT / 'scripts/construction/TurretRange.lua'
report = {'result': 'PASS', 'scope': 'Lua retained heap and blueprint cache lifecycle; no native/GPU/Web acceptance',
          'productionSha256': hashlib.sha256(production.read_bytes()).hexdigest(),
          'candidateSha256': hashlib.sha256(candidate.read_bytes()).hexdigest(),
          'production': measure(production), 'candidate': measure(candidate)}
stamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%S-%fZ')
output = ROOT / ('docs/migration/evidence/turret-cache-memory-' + stamp + '.json')
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
print(output)
