local Unit=require 'combat.CarUnit'
local Metrics=require 'drive.TrialMetrics'
local Overlay=require 'ui.DriveOverlay'
local function Near(a,b)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(a)~=type(b) then return false end
    if type(b)=='number' then return math.abs(a-b)<1e-7 end
    if type(b)~='table' then return a==b end
    for k,v in pairs(b) do if not Near(a[k],v) then return false end end
    return true
end
local function Make(c,many)
    local records={};local parts,hp={},{}
    for i=1,many and 3 or 1 do parts[i]={type=c.type or 'cube',_cells={{0,0,i}}};hp[i]=c.hp or 30 end
    local u=setmetatable({alive=true,combat=true,hp=hp,shields={},hull=require('combat.ArenaData').hull,struct=many and 0 or 90,
        bodyHp=c.bodyHp or 400,bodyHpMax=1000,incomingDamageMultiplier=c.multiplier or 1,lostCells=0,lostMajor=0,
        bp={parts=parts},env={time=10,viewEvents={},fx={}},vehicle={body={rotation=function() return {x=0,y=0,z=0,w=1} end}}},Unit)
    u.env.RecordDamage=function(_,target,amount,point,opts) records[#records+1]={amount=amount,partId=opts and opts.partId or cjson.null,
        shield=opts and opts.shield==true or false,pierce=opts and opts.pierce==true or false,broke=opts and opts.broke==true or false} end
    u.Destroy=function(self,id) self:CountLost(parts[id]);parts[id]=nil;hp[id]=nil;self.shields[id]=nil end
    u.Local=function(_,p) return p end;u.ShieldOf=function(self,id) return self.shields[id].v end
    u.March=function(_,p,d,len,skip) for i=1,3 do if hp[i] and not(type(skip)=='table' and skip[i] or skip==i) then return i end end end
    if (c.shield or 0)>0 then u.shields[1]={v=c.shield,hit=0,t=0} end
    return u,records
end
V.atFrame(40,function()
    local file=assert(io.open('tools/migration/source-damage-parity.json'));local fixtures=cjson.decode(file:read('*a'));file:close()
    for i,row in ipairs(fixtures.lives) do
        local c=row.input;local u=setmetatable({alive=c.alive,hull=c.hullEnabled and {} or nil,hullMin=type(c.hullMin)=='number' and c.hullMin or nil,
            Core=function() return {hp=c.core*100,max=100} end,Integrity=function() return c.integrity end,Health=function() return c.health end},Unit)
        V.assert(Near(u:Life(),row.expected),'source core, wreck and hull remaining life '..i)
    end
    for i,row in ipairs(fixtures.rows) do
        local c=row.input;local u,records=Make(c)
        local dealt=u:Damage(1,c.amount,{0,0,0},{armor=c.armor})
        local actual={dealt=dealt,hp=u.hp[1] or 0,bodyHp=u.bodyHp,struct=u.struct,shield=u.shields[1] and u.shields[1].v or 0,
            lostCells=u.lostCells,lostMajor=u.lostMajor,records=records}
        local ok=Near(actual,row.expected)
        if not ok then print('[DamageMismatch] '..i..' '..cjson.encode(actual)..' expected='..cjson.encode(row.expected)) end
        V.assert(ok,'source layered armor bypass and shield overflow '..i)
    end
    for i,row in ipairs(fixtures.rays) do
        local u,records=Make(row.input,true);local splash=nil ---@type table|nil
        u.Explode=function(_,point,radius,damage,opts) splash={point=point,radius=radius,damage=damage,armor=opts.armor};return 0 end
        local dealt=u:HitRay({owner={partId=1},point={0,0,0}},260,{0,0,1},row.input.pierce)
        local actual={dealt=dealt,bodyHp=u.bodyHp,hp={u.hp[1] or 0,u.hp[2] or 0,u.hp[3] or 0},records=records,splash=splash}
        local ok=Near(actual,row.expected)
        if not ok then print('[RayMismatch] '..i..' '..cjson.encode(actual)..' expected='..cjson.encode(row.expected)) end
        V.assert(ok,'source penetration carry, hull remainder and splash '..i)
    end
    local target={lostCells=0,lostMajor=0,cells0=300};local metrics=Metrics.New({})
    metrics:Damage(0,target,50,{0,0,0},false);metrics:Damage(0,target,20,{0,0,0},false,{pierce=true});metrics:Damage(0,target,80,{0,0,0},false,{shield=true})
    local p=metrics.pending[target];V.assert(p.amount==150 and p.normal==50 and p.pierce==20 and p.shield==80,'damage accounting keeps total and all three original pop channels')
    local o=setmetatable({index=0,pops={},Project=function() return 100,100 end},Overlay)
    for _=1,40 do o.pops[#o.pops+1]={t=1} end
    target.lostMajor=1;o:PopDamage(target,p)
    V.assert(o.index==3 and o.pops[1].broke==1 and o.pops[2].pierce and o.pops[3].shield,'normal, pierced and resisted rows preserve source break flag priority')
    V.assert(o.pops[1].x==o.pops[3].x and o.pops[2].y-o.pops[1].y==32 and o.pops[3].y-o.pops[2].y==32,'three rows share jitter and source 32px spacing')
    p.killed=true;o:PopDamage(target,p)
    V.assert(o.index==5 and o.pops[4].killed and o.pops[4].text=='70' and o.pops[5].y-o.pops[4].y==34,'kill combines body and pierce, excludes shields, uses source numeric-only text')
    V.finish()
end)
