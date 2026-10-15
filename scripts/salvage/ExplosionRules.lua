-- Frozen salvageFx.js dynamics. Sink owns presentation; rules never rebuild geometry.
local M={};M.__index=M
local function Copy(p) return {p[1],p[2],p[3]} end
local function Add(p,v,k) return {p[1]+v[1]*k,p[2]+v[2]*k,p[3]+v[3]*k} end
local function Normal(x,y,z) local n=math.sqrt(x*x+y*y+z*z);if n==0 then return {0,0,0} end;return {x/n,y/n,z/n} end
local function Pool(n) local t={};for i=1,n do t[i]={on=false,life=0,max=0} end;return t end
function M.New(rand,sink)
    return setmetatable({rand=rand or math.random,sink=sink,clock=0,shake=0,fire=Pool(240),core=Pool(40),smoke=Pool(200),embers=Pool(600),
        fi=1,ki=1,si=1,ei=1,ri=1,li=1,rings={{t=9},{t=9},{t=9},{t=9}},lights={{t=9,peak=0},{t=9,peak=0}},brands={},fires={},timers={}},M)
end
function M:R(a,b) return a+self.rand()*(b-a) end
function M:Puff(kind,p,v,s0,s1,max,opts)
    opts=opts or {};local key=kind=='fire' and 'fi' or kind=='core' and 'ki' or 'si';local pool=self[kind];local index=self[key];local q=pool[index]
    self[key]=index%#pool+1;q.on=true;q.life=-(opts.delay or 0);q.max=max;q.kind=kind;q.p=Copy(p);q.v=Copy(v);q.s0=s0;q.s1=s1
    q.heat=opts.heat or 0;q.op=opts.op or 1;q.rise=opts.rise or 0;q.dark=opts.dark or .18
    q.rotation=self.rand()*math.pi*2;q.spin=self:R(-1,1)*(kind=='fire' and 1.5 or .4);q.rotationBase=q.rotation;q.active=false
    if self.sink then self.sink:Spawn(kind,index,q,self.clock) end;return q
end
function M:Embers(p,n,speed)
    for _=1,n do local i=self.ei;self.ei=i%600+1;local q=self.embers[i];local a=self.rand()*math.pi*2;local e=self:R(.15,1.1);local s=speed*self:R(.35,1)
        q.p=Copy(p);q.v={math.cos(a)*math.cos(e)*s,math.sin(e)*s,math.sin(a)*math.cos(e)*s};q.life=0;q.max=self:R(.8,2.4);q.on=true
        if self.sink then self.sink:Spawn('embers',i,q,self.clock) end
    end
end
function M:Explode(pos,size,big)
    local p=Copy(pos);local s=math.max(2.5,size or 3)*(big and 1.5 or 1)
    local light=self.lights[self.li];self.li=self.li%2+1;light.p=Add(p,{0,1,0},3);light.t=0;light.peak=big and 2600 or 1400;light.dur=big and .9 or .6
    local ring=self.rings[self.ri];self.ri=self.ri%4+1;ring.p=Add(p,{0,1,0},-.6);ring.t=0;ring.r=s*3.2;ring.dur=.45
    self.shake=math.max(self.shake,big and 1.6 or 1)
    for _=1,big and 8 or 5 do
        local off={self:R(-1,1),self:R(0,1),self:R(-1,1)}
        self:Puff('core',Add(p,off,s*.3),{0,s,0},s*1.2,s*2.4,self:R(.35,.7),{op=.85})
    end
    for _=1,big and 30 or 20 do
        local d=Normal(self:R(-1,1),self:R(-.2,1),self:R(-1,1));local origin=Add(p,d,s*.25);local v=Add({0,s*.6,0},d,s*self:R(1.2,3.2))
        self:Puff('fire',origin,v,s*self:R(.7,1.1),s*self:R(1.8,2.8),self:R(.8,1.4),{heat=self:R(-.1,.3),rise=3.5})
    end
    local rounds=big and {{.18,.7},{.42,.6},{.75,.5}} or {{.22,.6},{.5,.45}}
    for _,round in ipairs(rounds) do
        local delay,k=round[1],round[2];local off={self:R(-1,1)*s,self:R(0,.8)*s,self:R(-1,1)*s};local at=Add(p,off,1)
        for _=1,8 do
            local d=Normal(self:R(-1,1),self:R(0,1),self:R(-1,1));local v=Add({0,0,0},d,s*k*self:R(1.5,3))
            self:Puff('fire',at,v,s*k*.8,s*k*self:R(2,3),self:R(.5,.9),{delay=delay,heat=.05,rise=2})
        end
        self.timers[#self.timers+1]={t=delay,p=at}
    end
    for _=1,big and 22 or 14 do
        local d={self:R(-.6,.6),1,self:R(-.6,.6)};local at=Add(p,{self:R(-1,1)*s*.6,s*.4,self:R(-1,1)*s*.6},1)
        self:Puff('smoke',at,Add({0,0,0},d,self:R(2,5)),s*1.4,s*self:R(4.5,7),self:R(4,6.5),{delay=self:R(.3,.8),op=1,rise=1.8,dark=self:R(.03,.08)})
    end
    self:Embers(p,big and 160 or 100,big and 26 or 20)
    for _=1,big and 9 or 6 do local a=self.rand()*math.pi*2;local e=self:R(.5,1.2);local sp=self:R(10,20)
        self.brands[#self.brands+1]={p=Copy(p),v={math.cos(a)*math.cos(e)*sp,math.sin(e)*sp,math.sin(a)*math.cos(e)*sp},t=0,max=self:R(.9,1.6),acc=0,S=s}
    end
    self.fires[#self.fires+1]={p=Add(p,{0,1,0},-.5),t=0,max=big and 14 or 9,acc=0,S=s}
end
local function Retain(list,predicate)
    local n=1;for i=1,#list do local q=list[i];if predicate(q) then list[n]=q;n=n+1 end end;for i=#list,n,-1 do list[i]=nil end
end
function M:Update(dt)
    self.clock=self.clock+dt
    for _,q in ipairs(self.timers) do q.t=q.t-dt end
    for _,q in ipairs(self.timers) do if q.t<=0 then self:Embers(q.p,40,14);self.shake=math.max(self.shake,.4) end end
    Retain(self.timers,function(q) return q.t>0 end)
    for _,kind in ipairs({'fire','core','smoke'}) do for i,q in ipairs(self[kind]) do if q.on then
        q.life=q.life+dt
        if q.life>=q.max then q.on=false;if self.sink then self.sink:Hide(kind,i) end
        elseif q.life>=0 then
            local damp=math.exp(-(kind=='smoke' and .9 or 3.2)*dt)
            q.v[1]=q.v[1]*damp;q.v[2]=q.v[2]*damp+q.rise*dt;q.v[3]=q.v[3]*damp
            for j=1,3 do q.p[j]=q.p[j]+q.v[j]*dt end;q.rotation=q.rotation+q.spin*dt
            if not q.active then q.active=true;q.rotationBase=q.rotation-q.spin*q.life;if self.sink then self.sink:Activate(kind,i,q) end end
            if self.sink then self.sink:Move(kind,i,q) end
        end
    end end end
    for i,q in ipairs(self.embers) do
        if q.life>=q.max then if q.on then q.on=false;if self.sink then self.sink:Hide('embers',i) end end
        else
            q.life=q.life+dt;q.v[2]=q.v[2]-14*dt;local k=math.exp(-.8*dt);q.v[1]=q.v[1]*k;q.v[3]=q.v[3]*k
            for j=1,3 do q.p[j]=q.p[j]+q.v[j]*dt end;if self.sink then self.sink:Move('embers',i,q) end
        end
    end
    for i,q in ipairs(self.rings) do
        if not q.dur then q.t=q.t+dt;q.visible=false
        elseif q.t>q.dur then q.visible=false
        else q.t=q.t+dt;local u=q.t/q.dur;q.visible=true;q.scale=1+math.sqrt(u)*q.r;q.opacity=math.max(0,(1-u)*.45) end
        if self.sink then self.sink:Ring(i,q) end
    end
    for i,q in ipairs(self.lights) do
        if q.t>(q.dur or .5) then q.intensity=0 else q.t=q.t+dt;local u=q.t/q.dur;q.intensity=q.peak*(1-u)^2*(.8+self.rand()*.4) end
        if self.sink then self.sink:Light(i,q) end
    end
    for _,f in ipairs(self.fires) do
        f.t=f.t+dt;f.acc=f.acc+dt;local k=1-f.t/f.max
        while f.acc>.12 do f.acc=f.acc-.12;if k<=0 then break end
            local o=Add(f.p,{self:R(-1,1)*f.S*.5,0,self:R(-1,1)*f.S*.5},1)
            self:Puff('fire',o,{0,self:R(2,4),0},f.S*.5*k+.4,f.S*.95*k+.6,self:R(.5,.9),{heat=self:R(-.05,.2),rise=2.5})
            if self.rand()<.5 then self:Puff('smoke',Add(o,{0,1,0},f.S*.6),{self:R(-.5,.5),self:R(2,3.5),self:R(-.5,.5)},f.S*.5,f.S*2.4,self:R(2.5,4),{op=.5*k+.15,rise=.6,dark=.12}) end
        end
    end
    Retain(self.fires,function(f) return f.t<f.max end)
    for _,b in ipairs(self.brands) do
        b.t=b.t+dt;b.acc=b.acc+dt;b.v[2]=b.v[2]-16*dt;for j=1,3 do b.p[j]=b.p[j]+b.v[j]*dt end
        while b.acc>.035 do
            b.acc=b.acc-.035;local k=1-b.t/b.max
            self:Puff('fire',b.p,{0,1,0},.5+b.S*.18*k,.9+b.S*.3*k,.35,{heat=.05,rise=1})
            if self.rand()<.4 then self:Puff('smoke',b.p,{0,1.5,0},.6,2.4,1.6,{op=.6,dark=.08,rise=.4}) end
        end
    end
    Retain(self.brands,function(b) return b.t<b.max end);self.shake=self.shake*math.exp(-5*dt)
    if self.sink then self.sink:Clock(self.clock) end
end
return M
