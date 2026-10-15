local Assist=require 'combat.AimAssist'
local function Near(a,b)
    if b==cjson.null then return a==nil or a==cjson.null end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-7*math.max(1,math.abs(b)) end
    if type(a)~='table' then return a==b end
    for k,v in pairs(b) do if not Near(a[k],v) then print('[AimGolden] mismatch '..tostring(k)..' actual='..tostring(a[k])..' expected='..tostring(v));return false end end;return true
end
V.atFrame(40,function()
    local file=File('tools/migration/source-aim-fixtures.json',FILE_READ);local data=cjson.decode(file:ReadString());file:Dispose()
    for i,row in ipairs(data.cases) do
        local self={pos={0,1,0},team='blue',vehicle={body={}}};local units={self}
        for _,u in ipairs(row.units) do local parts={};for _,p in ipairs(u.parts) do parts[p.id]=p end
            local unit={id=u.id,pos=u.pos,alive=u.alive,team=u.team,bp={parts=parts},vehicle={spec={bounds={min={-2,-1,-3},max={2,3,3}}},body={translation=function()return {x=u.pos[1],y=u.pos[2],z=u.pos[3]}end,rotation=function()return u.q end,linvel=function()return {x=row.speed,y=0,z=0}end}}};units[#units+1]=unit
        end
        local hit;if type(row.hit)=='table' then hit={point=row.hit.point,dist=row.hit.dist,owner={ref=type(row.hit.ref)=='number' and units[row.hit.ref+2] or nil}} end
        local cast=function(p,d,len)return {point={p[1]+d[1]*(len-1),p[2]+d[2]*(len-1),p[3]+d[3]*(len-1)},owner={ref=units[2]}}end
        local out=Assist.Apply(row.origin,row.dir,hit,self,units,cast,row.stats,row.wide)
        if out then out={point=out.point,ref=out.ref.id,partId=out.partId,slow=out.slow} end
        V.assert(Near(out,row.out),'source exposed-cell aim assist '..i..'/'..row.mode..'/'..row.wide)
    end;V.finish()
end)
