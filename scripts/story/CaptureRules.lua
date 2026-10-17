-- Frozen KINDS.capture: guards -> uncontested capture -> counterattack -> scrub.
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New() return setmetatable({p=0,phase='go',scrub=0,contested=0},M) end
function M:Update(r,dt,world)
    local s=r:StepSpec();local pos=world.pos;local spawned=nil;local counterAdded=0
    if self.phase=='go' and Flat(pos,s.pos)<s.trigger then
        self.phase='cap';r:Emit('spawn',{enemies=s.guards,tag='guard'})
        spawned=s.guards
        r:Emit('banner',{kick='遭遇守卫',title=s.guardTitle or '海盗守点队',sub=#s.guards..' 辆 · 狐狐海盗团',kind='enemy',ms=2600})
        r:Emit('say',{lines=s.alert,urgent=true});r:Emit('radio',{cue='alert'})
        r:Emit('hideBeacon')
    end
    r.inside=false;r.blocked=false;r.retitle=s.title
    if self.phase=='cap' then
        r.inside=r:Near(pos,s.pos,s.r,7,world.size);self.contested=0
        for _,p in ipairs(world.enemyPositions or {}) do if Flat(p,s.pos)<s.r*1.8 then self.contested=self.contested+1 end end
        for _,enemy in ipairs(spawned or {}) do
            local p=type(enemy.at)=='table' and enemy.at or world.nav and world.nav.nodes[enemy.at]
            local offset=enemy.off or {0,0};local z=p and (#p==3 and p[3] or p[2])
            if p and math.sqrt((p[1]+offset[1]-s.pos[1])^2+(z+offset[2]-s.pos[3])^2)<s.r*1.8 then self.contested=self.contested+1 end
        end
        r.blocked=self.contested>0
        if r.inside and not r.blocked then self.p=self.p+dt/(s.capSec or 6)
        elseif not r.inside then self.p=math.max(0,self.p-dt*.12) end
        r.progress=self.p
        if self.p>=1 then
            r.inside=false;r:Emit('siteCaptured',{id=s.site});r.stats.sites=(r.stats.sites or 0)+1
            r.checkpoint={pos={s.pos[1],s.pos[2]+1.5,s.pos[3]+8},yaw=0}
            r:Emit('banner',{kick='夺回采集器',title='采集器 '..s.site,sub=r.stats.sites..' / 3 · 狐狐的旗子已拔',kind='install',ms=2400})
            r:Emit('radio',{cue='install'})
            r:Emit('say',{lines=s.capLines,urgent=true})
            if s.counter then self.phase='counter';r:Emit('spawn',{enemies=s.counter,tag='counter'})
                counterAdded=#s.counter
                r:Emit('banner',{kick='海盗反扑',title=s.counterTitle or '反扑',sub='把采集器守住',kind='enemy',ms=2600})
                r:Emit('radio',{cue='alert'})
            else self.phase='scrub' end
        end
    end
    if self.phase=='counter' then
        local tags=world.enemyTags or {};local counter=(tags.counter or 0)+counterAdded
        r.retitle='顶住反扑 '..(#s.counter-counter)..' / '..#s.counter
        if counter==0 and (tags.guard or 0)==0 then self.phase='scrub';r:Emit('say',{lines=s.afterCounter}) end
    end
    if self.phase=='scrub' then
        r.inside=r:Near(pos,s.pos,9,6,world.size)
        if r.inside and world.interact then self.scrub=self.scrub+dt else self.scrub=math.max(0,self.scrub-dt*.6) end
        r.progress=self.scrub/1.6;r.retitle='擦掉采集器上的涂鸦'
        if self.scrub>=1.6 then r:Emit('scrub',{id=s.site});r.stats.graffiti=(r.stats.graffiti or 0)+1;return true end
    end
    return false
end
return M
