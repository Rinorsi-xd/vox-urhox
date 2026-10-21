-- Lua CPU only. Excludes native mesh upload, Bullet, rendering and frame rate.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
package.loaded['core.ResourceData']={Read=readData}
local Surface=require 'render.JoinedSurface'
local previous=assert(load(oldSource('render/JoinedSurface')))()
local function Median(values) table.sort(values);return values[(#values+1)//2] end
local function Time(fn) local start=os.clock();fn();return (os.clock()-start)*1000 end
local function Case(name,parts,remove)
    local remaining={};for i,p in ipairs(parts) do if i~=remove then remaining[#remaining+1]=p end end
    local oldInitial,newInitial,oldDamage,newDamage={},{},{},{}
    local cache
    previous.Build(parts);Surface.BuildCached(parts,{})
    for i=1,21 do
        collectgarbage('collect');oldInitial[i]=Time(function() previous.Build(parts) end)
        collectgarbage('collect');newInitial[i]=Time(function() Surface.BuildCached(parts,{}) end)
        collectgarbage('collect');oldDamage[i]=Time(function() previous.Build(remaining) end)
        cache={};Surface.BuildCached(parts,cache);collectgarbage('collect')
        newDamage[i]=Time(function() Surface.BuildCached(remaining,cache) end)
    end
    print(string.format('[P0Bench] %s parts=%d initial_old_ms=%.3f initial_new_ms=%.3f damage_old_ms=%.3f damage_new_ms=%.3f rebuilt=%d samples=21 median',
        name,#parts,Median(oldInitial),Median(newInitial),Median(oldDamage),Median(newDamage),cache.rebuiltParts))
end
local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),'vanguard')
local parts=bp:List();local remove
for i,p in ipairs(parts) do if Surface.IsJoined(p) then remove=i;break end end
Case('vanguard',parts,assert(remove))
local dense={}
for x=0,7 do for y=0,3 do for z=0,7 do dense[#dense+1]={id=#dense+1,type='cube',pos={x,y,z},rot=0,g=1,color=0xff8844} end end end
Case('dense',dense,100)
