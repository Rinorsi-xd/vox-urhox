local ResourceData=require("core.ResourceData")

local Loot=require 'salvage.Loot'
local Data=require('core.ResourceData').Read('Salvage/RunData.json')
local M={};M.__index=M
local function Flat(a,b) return math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2) end
function M.New(gp,op,rand)
    local self=setmetatable({},M);self:init(gp,op,rand);return self
end
function M:init(gp,op,rand)
    self.op=op;self.rand=rand or math.random;self.time=0;self.heat=0;self.cargo={};self.sessions={};self.objects={};self.extracts={}
    self.opened={};self.openedCount=0;self.kills=0;self.finished=false;self.events={};self.loot={red=0};self.exLeft={};self.airdrops={360,600}
    local vaults={}
    for _,group in ipairs({gp.loot,gp.wrecks}) do for _,source in ipairs(group) do
        local o={};for key,value in pairs(source) do o[key]=value end;o.g={-o.x,o.y,o.z}
        if o.kind=='crate' then o.ctype=Loot.Container(o.tier,o.id);if o.ctype=='vault' then vaults[#vaults+1]=o end end
        self.objects[#self.objects+1]=o
    end end
    -- Uniform shuffle avoids comparator RNG inconsistencies while preserving
    -- the source's intended random subset of open vaults for each operation.
    for i=#vaults,2,-1 do local j=math.floor(self.rand()*i)+1;vaults[i],vaults[j]=vaults[j],vaults[i] end
    for i=op.vaults+1,#vaults do vaults[i].ctype='electronics' end
    for _,source in ipairs(gp.extracts) do local e={};for k,v in pairs(source) do e[k]=v end;e.g={-e.x,e.y,e.z};self.extracts[#self.extracts+1]=e end
end
function M:Emit(kind,data) data=data or {};data.type=kind;self.events[#self.events+1]=data end
function M:Drain() local out=self.events;self.events={};return out end
function M:Heat(n) self.heat=math.min(100,self.heat+n) end
function M:Reach(o) return o.kind=='crate' and 14 or o.model=='core' and 24 or o.kind=='wreck' and 18 or 16 end
function M:Target(pos)
    local best,dist=false,math.huge
    for _,o in ipairs(self.objects) do local d=Flat(o.g,pos)
        if not self.opened[o.id] and d<self:Reach(o) and d<dist and math.abs(o.g[2]-pos[2])<12 then best=o;dist=d end
    end;return best
end
function M:Title(o)
    if o.ctype then return Data.containers[o.ctype].name end
    if o.kind=='wreck' then return o.model=='core' and '核心件 · '..o.name or Data.wrecks[o.model].name end
    return o.name..(o.kind=='kill' and ' 残骸箱' or ' 补给箱')
end
function M:Open(o)
    local s=self.sessions[o.id]
    if not s then
        s={o=o,title=self:Title(o),i=1,p=0,wait=0,value=0,done=false,crack=o.ctype=='vault' and 0 or nil}
        s.items=o.ctype and Loot.Roll(o.ctype,self.rand,self.loot,self.op,o.region) or Loot.FromTable(o.loot,self.rand)
        self.sessions[o.id]=s
        if o.kind=='crate' then self:Heat(({3,5,8,12})[o.tier+1]);if o.tier==2 then self:Emit('noise',{at=o.g,r=160}) end end
    end
    self.search=s;self.act=nil
end
function M:SearchStep(dt,state)
    local s=self.search;local o=s.o
    if s.crack and s.crack<8 then
        local slow=math.abs(state.speed)<2
        if state.hold and slow then
            if not s.loud then
                s.loud=true;self:Heat(20);self:Emit('noise',{at=o.g,r=520})
                self:Emit('vaultStart');self:Emit('hunt',{n=2,at=o.g})
            end
            s.crack=s.crack+dt
            if s.crack>=8 then
                local best=0;for _,item in ipairs(s.items) do best=math.max(best,item.r) end
                self:Emit('vaultOpened',{at=o.g,rarity=best})
            end
        end
        self.prompt={title='舰载保险库',sub=slow and (state.hold and '破解中… 别松手' or '停稳了 · 按住 E 破解 8 秒') or '车太快了 · 先停下',progress=s.crack/8,blocked=not slow};return
    end
    local it=s.items[s.i]
    if it then
        if it.state=='hidden' then it.state='scan' end
        if it.r>=4 and s.i==#s.items and not s.held then s.held=true;s.wait=.6;self:Emit('suspense',{rarity=it.r}) end
        if s.wait>0 then s.wait=s.wait-dt else s.p=s.p+dt/it.t end
        if s.p>=1 then
            local k=Loot.Take(self.cargo,it.id,it.n);it.left=it.n-k;it.state=it.left>0 and 'full' or 'shown';s.value=s.value+Loot.Price(it.id)*it.n
            self:Emit('reveal',{item=it,taken=k,at=o.g})
            if k>0 then self:Emit('cargoPickup',{items={{it.id,k}}}) end
            s.i=s.i+1;s.p=0
            if it.r==5 then self:Heat(40);self:Emit('noise',{at=o.g,r=900});self:Emit('hunt',{n=3,at=o.g}) end
        end
    elseif not s.done then s.done=true;s.doneAt=self.time;self.opened[o.id]=true;self.openedCount=self.openedCount+1;self:Emit('hide',{id=o.id}) end
    local full=false;for _,item in ipairs(s.items) do if item.state=='full' then full=item;break end end
    if full and state.swap then
        local before=full.left
        local dropped=Loot.Swap(self.cargo,full)
        local taken=before-full.left
        if taken>0 then self:Emit('cargoPickup',{items={{full.id,taken}},swap=true}) end
        if #dropped>0 then
            self:Emit('cargoDropped',{items=dropped})
            self:AddExtra({id='drop'..#self.objects,kind='cache',name='丢下的货',tier=0,g={state.pos[1],state.pos[2]-.8,state.pos[3]},loot=dropped})
        end
    end
    s.foot=full and 'F · 丢掉最便宜的一格换入' or s.done and '搜完了' or '开远了会收起 · 没搜完的留在箱子里'
    if s.done and not full and self.time-s.doneAt>1.5 then self.search=nil end
end
function M:AddExtra(o) self.objects[#self.objects+1]=o;self:Emit('crate',{object=o}) end
function M:ExitCheck(e,width)
    if e.openAt and self.time<e.openAt then return math.ceil((e.openAt-self.time)/60)..' 分钟后开放' end
    if e.needs and (self.cargo[e.needs] or 0)<1 then return '需要 1 个'..ResourceData.Read('UI/Outgame.json').items[e.needs].name end
    if e.maxWidth and width>e.maxWidth then return string.format('车宽 %.1f 米，超过 %d 米过不去',width,e.maxWidth) end
end
function M:Objective(pos)
    local best=false;local distance=math.huge
    local wantOut=self.time>600 or Loot.Used(self.cargo)>=15
    if not wantOut then
        for _,o in ipairs(self.objects) do if o.kind=='wreck' and o.model=='core' and not self.opened[o.id] then
            local d=Flat(o.g,pos);if d<distance then distance=d;best={text='核心件 · '..o.name,g=o.g} end
        end end
    end
    if wantOut or not best then
        distance=math.huge
        for _,e in ipairs(self.extracts) do if not e.openAt or self.time>=e.openAt then
            local d=Flat(e.g,pos);if d<distance then distance=d;best={text='撤离 '..e.id..' · '..e.name,g=e.g} end
        end end
    end
    if not best then return nil end;best.dist=distance;return best
end
function M:Step(dt,state)
    if self.finished then return end
    self.time=self.time+dt;self.heat=math.max(0,self.heat-dt*.7);self.prompt=nil
    if not state.alive then self:Emit('failed',{reason='战车被击毁'});self.finished=true;return end
    if self.time>=900 then self:Emit('failed',{reason='超时 · 撤离窗口关闭'});self.finished=true;return end
    if state.firing then self:Heat(dt*1.5);self.fireTime=(self.fireTime or 0)+dt;if self.fireTime>.5 then self.fireTime=0;self:Emit('noise',{at=state.pos,r=180}) end end
    if self.airdrops[1] and self.time>=self.airdrops[1] then table.remove(self.airdrops,1);self:Emit('airdrop') end
    local inside=false;for _,e in ipairs(self.extracts) do if Flat(e.g,state.pos)<e.radius then inside=e;break end end
    if inside then
        local why=self:ExitCheck(inside,state.width)
        if why then self.prompt={title='撤离点 · '..inside.name,sub=why,blocked=true};self.ex=nil
        else
            if not self.ex or self.ex.e~=inside then
                local wait=self.exLeft[inside.id] or inside.wait
                self.ex={e=inside,left=wait,approachWait=wait}
                self:Emit('extractApproach',{exit=inside,wait=wait})
                if inside.loud and not inside.called then
                    inside.called=true;self:Heat(30);self:Emit('noise',{at=inside.g,r=600});self:Emit('hunt',{n=3,at=inside.g});self:Emit('extractSignal')
                end
            end
            self.ex.left=self.ex.left-dt;self.exLeft[inside.id]=self.ex.left
            if self.ex.left<=0 then self.finished=true;self:Emit('extracted',{exit=inside});return end
        end
    else self.ex=nil end
    if self.search and (self.ex or Flat(self.search.o.g,state.pos)>self:Reach(self.search.o)+6) then self.search=nil end
    if self.search then self:SearchStep(dt,state)
    elseif not self.ex then
        local o=self:Target(state.pos);self.target=o
        if o then
            if o.kind~='wreck' then self.prompt={title=self:Title(o),sub='按 E 打开搜索',progress=0};if state.tap then self:Open(o) end
            elseif Loot.Used(self.cargo)>=20 then self.prompt={title=self:Title(o),sub='货舱满了',blocked=true};self.act=nil
            else
                if not self.act or self.act.o~=o then self.act={o=o,t=0} end
                local need=o.model=='core' and 6 or Data.wrecks[o.model].time*.5
                self.act.t=state.hold and self.act.t+dt or math.max(0,self.act.t-dt*2)
                if state.hold then self:Heat(dt) end
                self.prompt={title=self:Title(o),sub=state.hold and '拆卸中…' or ('按住 E · '..need..' 秒'),progress=self.act.t/need}
                if self.act.t>=need then
                    local got=0;local picked={};local left={}
                    local rolled=Loot.FromTable(Data.wrecks[o.model].loot,self.rand)
                    -- World wrecks fill cargo in drop-table order; only search panels sort by rarity.
                    table.sort(rolled,function(a,b) return a.order<b.order end)
                    for _,it in ipairs(rolled) do
                        local taken=Loot.Take(self.cargo,it.id,it.n);if taken>0 then got=got+1;picked[#picked+1]={it.id,taken} end
                        if taken<it.n then left[#left+1]={it.id,it.n-taken} end
                        self:Emit('reveal',{item=it,at=o.g,taken=taken,worldBatch=true})
                    end
                    self:Emit('wreckLoot',{title=self:Title(o),items=picked,left=left,empty=#rolled==0,core=o.model=='core'})
                    if got>0 then
                        self:Emit('cargoPickup',{items=picked,worldBatch=true})
                        self:Emit('worldLoot',{at=o.g,color=o.model=='core' and 0xffb21e or 0xc9c1b2,n=got})
                    end
                    self.opened[o.id]=true;self.openedCount=self.openedCount+1;self:Heat(o.model=='core' and 25 or 6)
                    if o.model=='core' then self:Emit('noise',{at=o.g,r=380});self:Emit('hunt',{n=2,at=o.g});self:Emit('core',{at=o.g}) end;self.act=nil
                end
            end
        else self.act=nil end
    end
end
return M
