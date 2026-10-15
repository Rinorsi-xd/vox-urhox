local Config=require "Config"
local Defs=require "parts.Defs"
local Rot=require "core.Rotations"
local Mounts=require "parts.Mounts"
local M={}
local function Inside(points,center)
    local sorted={};for _,p in ipairs(points) do sorted[#sorted+1]={p[1],p[3]} end
    table.sort(sorted,function(a,b) return a[1]==b[1] and a[2]<b[2] or a[1]<b[1] end)
    local function Cross(a,b,c) return (b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]) end
    local function Half(reverse)
        local out={}
        for i=1,#sorted do
            local p=sorted[reverse and #sorted-i+1 or i]
            while #out>=2 and Cross(out[#out-1],out[#out],p)<=0 do table.remove(out) end
            out[#out+1]=p
        end
        table.remove(out);return out
    end
    local hull=Half(false);for _,p in ipairs(Half(true)) do hull[#hull+1]=p end
    if #hull<3 then return false end
    for i,p in ipairs(hull) do if Cross(p,hull[i%#hull+1],center)<-1e-6 then return false end end
    return true
end
function M.Compute(bp)
    local inf=math.huge
    local s={budget=0,mass=0,load=0,weapons=0,thrusters=0,count=0,decor=0,comY=0,
        loadL=0,loadR=0,hoverLoad=0,badHovers={},legCount=0,legLoad=0,mechCount=0,mechLoad=0,fire={},
        bb={minX=inf,maxX=-inf,minY=inf,maxY=-inf,minZ=inf,maxZ=-inf}}
    local speedW,forwardLimit,liftNewton,maxTier,comX,comZ=0,0,0,0,0,0
    local minX,maxX=inf,-inf
    local hoverPoints,fire={},{}
    for _,p in pairs(bp.parts) do
        local d=Defs.PARTS[p.type]
        s.count=s.count+1;s.budget=s.budget+d.budget;s.mass=s.mass+d.mass
        local hover=Mounts.HoverInfo(p.type,p.rot)
        local hoverWorks=not hover or Rot.ApplyRot(p.rot,hover.liftDir)[2]>=math.cos(35*math.pi/180)
        local legWorks=(not d.leg or Rot.ROTATIONS[p.rot].up[2]>0.99) and (not d.mech or Mounts.MechWorks(p.rot))
        if hover then
            if hoverWorks then
                s.hoverLoad=s.hoverLoad+d.load
                local lift=Rot.ApplyRot(p.rot,hover.lift.p)
                hoverPoints[#hoverPoints+1]={lift[1]+p.pos[1],lift[2]+p.pos[2],lift[3]+p.pos[3]}
            else s.badHovers[#s.badHovers+1]=p.id end
        end
        if d.leg and legWorks then s.legCount=s.legCount+1;s.legLoad=s.legLoad+d.load end
        if d.mech and legWorks then s.mechCount=s.mechCount+1;s.mechLoad=s.mechLoad+d.load end
        if d.load>0 and hoverWorks and legWorks then
            s.load=s.load+d.load;speedW=speedW+d.load*d.speed
            for _,c in ipairs(p._cells) do minX=math.min(minX,c[1]);maxX=math.max(maxX,c[1]) end
            if p.pos[1]<0 then s.loadL=s.loadL+d.load elseif p.pos[1]>0 then s.loadR=s.loadR+d.load end
        end
        if d.cat=="decor" then s.decor=s.decor+1 end
        if d.wtier then maxTier=math.max(maxTier,d.wtier) end
        if d.weapon then
            s.weapons=s.weapons+1
            local kind=p.type:match("^%a+")
            if not fire[kind] then
                fire[kind]={kind=kind,name=({mg="加特林",laser="激光",sniper="狙击"})[kind] or kind,count=0,share=0}
                s.fire[#s.fire+1]=fire[kind]
            end
            local f=fire[kind];f.count=f.count+1;f.share=f.share+1/(6-d.wtier);f.output=math.min(1,f.share)
        end
        if d.thruster then
            s.thrusters=s.thrusters+1
            local dir=Rot.ApplyRot(p.rot,d.thrustDir)
            liftNewton=liftNewton+math.max(0,dir[2])*d.thrust
            if dir[3]>0.7 or dir[2]>0.7 then forwardLimit=math.max(forwardLimit,d.speedLimit) end
        end
        local per=d.mass/#p._cells;local bb=s.bb
        for _,c in ipairs(p._cells) do
            s.comY=s.comY+per*(c[2]+0.5);comX=comX+per*c[1];comZ=comZ+per*c[3]
            bb.minX=math.min(bb.minX,c[1]);bb.maxX=math.max(bb.maxX,c[1])
            bb.minY=math.min(bb.minY,c[2]);bb.maxY=math.max(bb.maxY,c[2])
            bb.minZ=math.min(bb.minZ,c[3]);bb.maxZ=math.max(bb.maxZ,c[3])
        end
    end
    s.L=s.load>0 and s.mass/s.load or inf
    local factor=s.L>2 and 0 or math.max(0,math.min(1,1.25-0.5*s.L))
    s.topSpeed=math.max(s.load>0 and speedW/s.load*factor or 0,forwardLimit)
    s.liftRatio=liftNewton/math.max(1,s.mass*9.81);s.parts=s.count-s.decor
    local bb=s.bb
    s.dims=s.count>0 and {L=bb.maxZ-bb.minZ+1,W=bb.maxX-bb.minX+1,H=bb.maxY-bb.minY+1} or {L=0,W=0,H=0}
    s.comY=s.mass>0 and s.comY/s.mass or 0
    s.trackWidth=maxX>=minX and maxX-minX+1 or 0
    s.hoverOffCenter=#hoverPoints>0 and not Inside(hoverPoints,{comX/math.max(1,s.mass),comZ/math.max(1,s.mass)})
    for _,t in ipairs(Config.TIERS) do
        if s.budget<=t.budget and s.mass<=t.mass and s.parts<=t.parts and s.decor<=t.decor and s.weapons<=t.weapons and maxTier<=t.id then s.fitTier=t;break end
    end
    return s
end
return M
