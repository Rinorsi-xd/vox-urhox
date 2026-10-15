local Driver=require('combat.DrillRaiderDriver')
local function Near(a,b)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-8 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(b) do if not Near(a[k],v) then return false end end;return true
end
V.atFrame(40,function()
    local f=assert(io.open('tools/migration/source-drill-raider.json'));local data=cjson.decode(f:read('*a'));f:close()
    for i,row in ipairs(data.rows) do
        -- JSON's native decoder may round the last mantissa bit. Preserve the
        -- actual source double at the exact 20/32m branch boundaries.
        for k,hex in ipairs(row.aimBits) do local bytes=hex:gsub('..',function(s) return string.char(tonumber(s,16)) end);row.aim[k]=string.unpack('<d',bytes) end
        local cancelled=0;local drill={held=row.held and {} or nil};drill.Cancel=function(self) self.held=nil;cancelled=cancelled+1 end
        local body={translation=function() return {x=0,y=1,z=0} end,rotation=function() return {x=0,y=0,z=0,w=1} end,linvel=function() return {x=0,y=0,z=row.speed} end}
        local vehicle={body=body,spec={bounds={min={-2,-1,-2},max={2,2,2}}},Yaw=function() return 0 end}
        local w={stats={drill=true},cool=0,windup=row.windup};local sys={drill=drill,Group=function() return {weapons={w}} end,Muzzle=function() return {pos={0,0,0},dir={0,0,1}} end}
        local driver=setmetatable({unit={vehicle=vehicle},width=4,chargeWait=0,world={space={Raycast=function(_,p,d,len) return d[2]==-1 and {point={p[1],0,p[3]},dist=p[2]} or nil end}}},Driver)
        driver.Visible=function() return true end
        local result=driver:Policy(1/60,{command={throttle=.77,steer=.11,handbrake=false},aim={99,0,0},trigger=true,mode='approach'},{vehicle=vehicle,aim=row.aim,system=sys,shield={active=false}})
        local ok=Near(result,row.result) and cancelled==row.cancelled and math.abs((driver.chargeWait or 0)-(row.chargeWait or 0))<1e-8
        if not ok then print('[RaiderMismatch] '..i..' actual='..cjson.encode(result)..' expected='..cjson.encode(row.result)) end
        V.assert(ok,'source drill raider spacing/alignment/charge '..i)
    end
    local damage=0;local unit={team='red',alive=true,endless={flingSelfDestruct=true},env={fx={}},pos={1,2,3},bp={CoreParts=function() return {{id=9}} end},Damage=function(_,id,amount) damage=damage+amount end,Flush=function() end}
    Driver.ArmExplosion(unit,{type='drill',stage='fling'});V.assert(unit.raiderFuse==.2,'enemy fling arms original 200ms fuse')
    Driver.StepExplosion(unit,.19);V.assert(damage==0,'fling motion survives before fuse')
    Driver.StepExplosion(unit,.01);V.assert(damage==1e9 and unit.raiderFuse==nil and unit.env.fx[1].type=='explode','fuse destroys core with original remote explosion')
    unit.team='blue';Driver.ArmExplosion(unit,{type='drill',stage='fling'});V.assert(unit.raiderFuse==nil,'player drill never arms enemy self destruction')
    V.finish()
end)
