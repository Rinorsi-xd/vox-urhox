local Rules=require 'salvage.ExplosionRules'
local file=assert(io.open('tools/migration/source-salvage-explosion-fixtures.json'));local fixture=cjson.decode(file:read('*a'));file:close()
local function Near(a,b,t) return a~=nil and math.abs(a-b)<(t or 2e-6)*math.max(1,math.abs(b)) end
local function Check(a,b,label,t) V.assert(type(b)=='number' and Near(a,b,t) or type(b)~='number' and a==b,label..': '..tostring(a)..' vs '..tostring(b)) end
local function Snapshot(r,s,label)
    for _,k in ipairs({'shake','fi','ki','si','ei'}) do Check(r[k],s[k],label..k) end
    for _,k in ipairs({'timers','brands','fires'}) do Check(#r[k],s[k],label..k) end
    for kind,pool in pairs(s.pools) do
        local count=0;for _,q in ipairs(r[kind]) do if q.on then count=count+1 end end;Check(count,pool.count,label..kind..'count')
        for _,it in ipairs(pool.items) do local q=r[kind][it.i];local at=label..kind..it.i..' '
            for _,k in ipairs({'on','life','max','s0','s1','heat','op','rise','dark','rotation','spin'}) do if it[k]~=nil and (k~='rotation' or it.spin~=nil) then Check(q[k],it[k],at..k) end end
            for _,k in ipairs({'p','v'}) do if it[k] then for i=1,3 do Check(q[k][i],it[k][i],at..k..i) end end end
        end
    end
    for _,it in ipairs(s.embers) do local q=r.embers[it.i];local at=label..'ember'..it.i..' '
        Check(q.life,it.life,at..'life',.00003);Check(q.max,it.max,at..'max',.00003)
        if it.max>0 and q.p then for _,k in ipairs({'p','v'}) do for i=1,3 do if k~='p' or q.on then Check(q[k][i],it[k][i],at..k..i,.0001) end end end end
    end
    for i,it in ipairs(s.rings) do local q=r.rings[i];Check(q.t,it.t,label..'ring t'..i)
        if it.r then Check(q.r,it.r,label..'radius');Check(q.dur,it.dur,label..'duration');if q.scale then Check(q.scale,it.scale,label..'scale');if q.visible then Check(q.opacity,math.max(0,it.opacity),label..'alpha') end end end
    end
    for i,it in ipairs(s.lights) do local q=r.lights[i];Check(q.t,it.t,label..'light t'..i)
        if it.peak then Check(q.peak,it.peak,label..'peak');if it.dur then Check(q.dur,it.dur,label..'duration') end;Check(q.intensity or 0,it.intensity,label..'intensity') end
    end
end
V.atFrame(10,function()
    for ci,c in ipairs(fixture.cases) do
        local seed=c.seed;local r=Rules.New(function() seed=(seed*1664525+1013904223)&0xffffffff;return seed/4294967296 end)
        r:Explode(c.pos,c.size,c.big);local frame=0
        for _,s in ipairs(c.snapshots) do while frame<s.frame do r:Update(fixture.dt);frame=frame+1 end;Snapshot(r,s,'case'..ci..' frame'..frame..' ') end
        V.assert(#r.fires==0 and #r.brands==0 and #r.timers==0,'source residual timers expire after fifteen seconds')
    end;V.finish()
end)
