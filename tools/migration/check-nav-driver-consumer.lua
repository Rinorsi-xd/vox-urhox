package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
for _,name in ipairs({'EnemyDriver','EnemyDriverThink','EnemyDriverMotion','EnemyDriverTactics'})do
    package.loaded['combat.'..name]=nil
end
package.loaded['combat.EnemyDriverNav']=assert(loadfile(NAV_CONSUMER_MODULE))()
local assertions,steps,rays=0,0,0
local function Encode(value)
    local kind=type(value)
    if kind=='number' then return string.format('%a',value) end
    if kind=='string' then return string.format('%q',value) end
    if kind~='table' then return tostring(value) end
    local keys={};for key in pairs(value)do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={'{'};for _,key in ipairs(keys)do out[#out+1]=Encode(key)..'='..Encode(value[key])..';'end
    out[#out+1]='}';return table.concat(out)
end
cjson={null=SOURCE_NULL,decode=function()return SOURCE_AI_DATA end}
File=function()return {ReadString=function()return 'source-fixtures'end,Dispose=function()end}end
V={assert=function(ok,message)assert(ok,message);assertions=assertions+1 end,
    atFrame=function(_,callback)callback()end,finish=function()end}
local Driver=require 'combat.EnemyDriver'
local new=Driver.New
Driver.New=function(world,...)
    local cast=world.CastRay
    world.CastRay=function(self,origin,direction,length,excluded,...)
        local result=cast(self,origin,direction,length,excluded,...)
        rays=rays+1;NAV_TRACE(Encode({'ray',origin,direction,length,excluded~=nil,result}))
        return result
    end
    local driver=new(world,...)
    local step=driver.Step
    driver.Step=function(self,...)
        local command,aim,fire,info=step(self,...);steps=steps+1
        NAV_TRACE(Encode({command=command,aim=aim,fire=fire,info=info,route=self.route,goal=self.goal,
            circle=self.circle,lane=self.lane,reaction=self.reaction,error=self.error,lag=self.lag,
            life=self.life,nextThink=self.nextThink,time=self.time,current=self.unit.weapons.current}))
        return command,aim,fire,info
    end
    return driver
end
assert(loadfile('tools/migration/check-enemy-driver.lua'))()
return {assertions=assertions,steps=steps,rays=rays}
