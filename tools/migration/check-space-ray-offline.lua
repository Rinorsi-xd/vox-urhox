local reads={body=0,node=0,id=0}
function Vector3(x,y,z)return {x=x,y=y,z=z}end
function Ray(origin,direction)return {origin=origin,direction=direction}end
package.loaded['core.Coord']={Vec=function(x,y,z)return Vector3(-x,y,z)end}
package.loaded['physics.Body']={Wrap=function(n)return {token='wrapped:'..n.key}end}
local old=assert(loadfile(NAV_BEFORE_ROOT..'/scripts/physics/Space.lua'))()
local current=assert(loadfile('scripts/physics/Space.lua'))()
local checks=0
local function Equal(a,b,label)
    checks=checks+1;assert(type(a)==type(b),label..' type')
    if type(a)=='table' then for k,v in pairs(a)do Equal(v,b[k],label..'.'..tostring(k))end
        for k in pairs(b)do assert(a[k]~=nil,label..' extra key')end
    else assert(a==b,label..' mismatch')end
end
local function Native(key,mass,kinematic,trigger)
    local node={GetID=function()reads.id=reads.id+1;return key end}
    return setmetatable({key=key,mass=mass,kinematic=kinematic,trigger=trigger},
        {__index=function(_,k)if k=='node' then reads.node=reads.node+1;return node end end})
end
local natives={Native(1,0,false,false),Native(2,0,false,true),Native(3,10,false,false),Native(4,0,true,false),Native(5,0,false,false),Native(6,0,false,false)}
local function Hit(n,i)
    return setmetatable({position=Vector3(i,.1,-i),normal=Vector3(.2,1,.3),distance=i*.1},
        {__index=function(_,k)if k=='body' then reads.body=reads.body+1;return n end end})
end
local results={Hit(nil,0)}
for i,n in ipairs(natives)do results[#results+1]=Hit(n,i)end
local origin,direction={1,2,3},{.2,-1,.3}
local function Run(mod,excluded,skip,fixed,registered,mask)
    local call
    local world={Raycast=function(_,ray,length,m)call={ray=ray,length=length,mask=m};return results end}
    local scene={GetComponent=function()return world end}
    local space=mod.New(scene)
    if registered then for _,n in ipairs(natives)do space.bodies[n.key]={body={token='registered:'..n.key},owner={type=n.key==5 and 'skip' or 'ground'}}end end
    reads={body=0,node=0,id=0}
    local result=space:Raycast(origin,direction,20,excluded and {native=natives[1]} or nil,skip and 'skip' or nil,fixed,mask)
    return {hit=result,call=call},reads
end
local cases={}
for _,excluded in ipairs({false,true})do for _,skip in ipairs({false,true})do for _,fixed in ipairs({false,true})do for _,registered in ipairs({false,true})do for _,mask in ipairs({false,0,255})do
    local a,ac=Run(old,excluded,skip,fixed,registered,mask or nil)
    local b,bc=Run(current,excluded,skip,fixed,registered,mask or nil)
    Equal(a,b,'ray filter/result')
    assert(bc.body<ac.body and bc.node<ac.node and bc.id<ac.id,'expected redundant native getter removal')
    cases[#cases+1]={excluded=excluded,skip=skip,fixed=fixed,registered=registered,mask=mask,before=ac,current=bc}
end end end end end
-- Exhaustion and owner filtering must still return nil.
results={Hit(natives[2],1),Hit(natives[4],2),Hit(natives[5],3)}
local a=Run(old,true,true,true,true);local b=Run(current,true,true,true,true)
Equal(a,b,'all rejected');assert(a.hit==nil and b.hit==nil,'all rejected returns nil')
return {result='PASSED',assertions=checks,cases=cases}
