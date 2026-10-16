-- Production batching with exact enable-state filtering and mask restoration.
package.path='scripts/?.lua;'..package.path
OUTSIDE=0
local Warmup=require 'render.SceneWarmup'
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function fixture()
    local groups={};local all={}
    local function add(kind,id,enabled,mask,outside,reject)
        local d={id=id,enabledEffective=enabled,viewMask=mask,worldBoundingBox={outside=outside},reject=reject}
        groups[kind]=groups[kind] or {};table.insert(groups[kind],d);all[#all+1]=d;return d
    end
    for i=1,18 do add('StaticModel','visible'..i,true,i+2,false,false) end
    for i=1,17 do add('CustomGeometry','disabled'..i,false,i+30,false,false) end
    add('AnimatedModel','disabled-parent',false,91,false,false)
    add('BillboardSet','unknown',nil,92,false,false)
    add('Terrain','outside',true,93,true,false)
    add('StaticModelGroup','rejected',true,94,false,true)
    add('Skybox','sky',true,95,true,false)
    add('StaticModel','zero',true,0,false,false)
    local scene={GetComponents=function(_,kind)return groups[kind]or{}end}
    local camera={frustum={IsInsideFast=function(_,bounds)return bounds.outside and OUTSIDE or 1 end}}
    return scene,camera,all
end
local function run(cancel)
    local scene,camera,all=fixture();local masks={}
    for _,d in ipairs(all) do masks[d]=d.viewMask end
    local w=Warmup.New(scene,8,camera,function(d)return not d.reject end)
    if COMPARE_BASELINE then
        local sequence={};local frames=0
        repeat
            frames=frames+1
            for _,d in ipairs(all)do
                if d.viewMask~=0 and d.enabledEffective~=false then sequence[#sequence+1]=d.id..':'..d.viewMask end
            end
        until w:Rendered()
        for _,d in ipairs(all)do assert(d.viewMask==masks[d],'comparison restore '..d.id)end
        return {sequence=table.concat(sequence,','),frames=frames}
    end
    check(w.disabled==18,'disabled drawable and disabled-parent child omitted')
    check(w.skipped==1,'outside counter excludes disabled')
    check(#w.items==20,'only enabled or unknown admitted')
    local admitted={};for _,item in ipairs(w.items)do admitted[item.drawable.id]=true end
    check(admitted.unknown and admitted.sky,'unknown state and sky conservatively retained')
    for _,d in ipairs(all) do
        if d.enabledEffective==false or d.reject or d.id=='outside' then
            check(d.viewMask==0,'excluded masks stay suppressed during batches')
        end
    end
    local submissions={};local frames=0
    repeat
        frames=frames+1
        for _,d in ipairs(all)do
            if d.viewMask~=0 and d.enabledEffective~=false and not d.reject and (not d.worldBoundingBox.outside or d.id=='sky')then
                submissions[d.id]=(submissions[d.id]or 0)+1
            end
        end
        if cancel then w:Restore();break end
    until w:Rendered()
    for _,d in ipairs(all)do check(d.viewMask==masks[d],'exact mask restore '..d.id) end
    if not cancel then
        check(frames==3,'no empty disabled-only batches')
        for id in pairs(admitted)do check(submissions[id]==1,'one enabled submission '..id)end
        check(w.batches==3,'three useful batches')
    end
    return frames
end
if COMPARE_BASELINE then return run(false) end
local frames=run(false);run(true)
return {checks=checks,disabled=18,admitted=20,frames=frames}
