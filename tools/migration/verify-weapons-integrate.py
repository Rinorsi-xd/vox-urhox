import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".tmp/nav-python-deps"))
from lupa.lua54 import LuaRuntime


def exercise(source):
    lua = LuaRuntime(encoding=None)
    math3 = lua.execute((ROOT / "scripts/core/Math3.lua").read_bytes())
    lua.globals()[b"Math3"] = math3
    lua.execute(b"""
        function require(name)
            if name=='core.Math3' then return Math3 end
            if name=='combat.WeaponDefs' then return {ENERGY={},DamageAtDistance=function(s,d)return s.damage+d*.01 end} end
            return {}
        end
    """)
    lua.globals()[b"Weapons"] = lua.execute(Path(source).read_bytes())
    return lua.execute(b"""
        local function Encode(v)
            local t=type(v)
            if t=='number' then return 'n'..string.pack('<d',v) end
            if t=='string' then return 's'..#v..':'..v end
            if t=='nil' then return 'nil' end
            if t=='boolean' then return v and 'true' or 'false' end
            local keys={};for k in pairs(v) do keys[#keys+1]=k end
            table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
            local out={'{'};for _,k in ipairs(keys)do out[#out+1]=Encode(k);out[#out+1]=Encode(v[k])end
            out[#out+1]='}';return table.concat(out)
        end
        local results={}
        for _,dt in ipairs({0,1/60,.1}) do
            for scenario=1,6 do
                local trace={};local input={};local originalPositions={}
                for i=1,3 do
                    local p={s={damage=5,impulse=2,tier=i},pos={i,2,i*3},vel={i*2,-i,i*7},life=.07*i,dist=10*i,bright=i==1}
                    if scenario==1 then p.vel={0,0,0} end
                    if scenario==2 then p.vel={1e-190,-1e-190,1e-190} end
                    if scenario==3 then p.pos[2]=-81 end
                    if scenario==4 then p.life=-1 end
                    originalPositions[i]=p.pos;input[i]=p
                end
                local sys=setmetatable({projectiles=input,fx={}},Weapons)
                local env={killHeight=-80,castRay=function(p,d,length,exclude)
                    trace[#trace+1]={'ray',p,d,length}
                    if scenario>=5 then return {point={9,8,7},normal={0,1,0},dist=.3,owner={type=scenario==5 and 'car' or 'ground'}} end
                end,hit=function(h,damage,dir,impulse,pierce)trace[#trace+1]={'hit',h,damage,dir,impulse,pierce}end}
                sys:Integrate(dt,{},env)
                local aliases={};for i,p in ipairs(sys.projectiles)do for j,old in ipairs(originalPositions)do if p.pos==old then aliases[#aliases+1]={i,j} end end end
                results[#results+1]=Encode({sys.projectiles,sys.fx,trace,aliases})
            end
        end
        return table.concat(results,'|'),#results
    """)


if __name__ == "__main__":
    before = ROOT / "docs/migration/evidence/perf-weapons-2026-10-16/before/WeaponSystem.lua"
    a, count = exercise(before)
    b, other_count = exercise(ROOT / "scripts/combat/WeaponSystem.lua")
    assert a == b and count == other_count, "Integration byte/state/output/alias mismatch"
    print(json.dumps({"result": "PASS", "cases": count, "scope": "Actual Lua 5.4 modules, exact binary floats/output/order/position alias behavior; zero and underflow velocities, dt0, expiry, kill-height, metal/ground hits. Non-homing edge fixture only."}))
