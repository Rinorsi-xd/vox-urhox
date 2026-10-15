-- The caller passes JSON-decoded records produced by combat-source-golden.cjs.
package.path='scripts/?.lua;'..package.path
local cases=...;assert(cases,'pass frozen H5 golden records')
package.loaded['render.EffectBatch']={};package.loaded['render.Quality']={current={name='desktop'}}
package.loaded['render.ChipEffects']={};package.loaded['render.MissileView']={}
package.loaded['core.ResourceData']={Read=function()return {sizes={['3']={l=1.07,r=.11}}}end}
local Combat=require'render.CombatEffects';local Missile=require'render.MissileEffects';local Source=require'render.CombatSourceFx'
local function equal(a,b,path)
 path=path or'';if type(a)~=type(b)then error(path..' type '..type(a)..' ~= '..type(b))end
 if type(a)=='number'then assert(math.abs(a-b)<1e-9,path..' '..a..' ~= '..b)
 elseif type(a)=='table'then for k,v in pairs(a)do equal(v,b[k],path..'/'..tostring(k))end;for k in pairs(b)do assert(a[k]~=nil,path..' extra '..tostring(k))end
 else assert(a==b,path..' unequal')end
end
for _,case in ipairs(cases)do
 local seed=146982;math.random=function()seed=seed*48271%2147483647;return seed/2147483647 end
 local rows={};local function Record(kind,...)rows[#rows+1]={kind=kind,args={...}}end
 local f=setmetatable({flares={},particles={},maxParticles=1000,zaps={},time=0,events=0},{__index=Combat})
 function f:Flash(...)Record('flash',...)end
 function f:Burst(p,n,s,c,normal,size,life,grav,up)Record('burst',p,n,s,c,normal or false,size or .08,life or .45,grav==nil and 12 or grav,up or .4)end
 function f:Puff(p,n,s,l,g)Record('puff',p,n,s,l,g or .35)end
 function f:Ring(p,d,r0,r1,l,c,a,t,delay)Record('ring',p,d,r0,r1,l,c,a or 1,t or .18,delay or 0)end
 function f:Flare(...)Record('flare',...)end
 function f:Spark(p,v,c,s,l,drag,grav,grow)Record('spark',p,v,c,s,l,drag or 0,grav or 0,grow or 0)end
 f.light={Emit=function(_,p,n,c,decay,smooth)Record('light',p,n,c or 0xffa050,decay or 18,smooth or 0)end}
 f.missiles=Missile.New(f)
 local e=case.event
 if e.type=='shot'then f:Shot(e)
 elseif e.type=='blast'then for i=1,e['repeat']do f:Consume({e})end
 elseif e.type=='dry'or e.type=='plateBreak'or e.type=='repair'or e.type=='heal'then f:Consume({e})
 elseif e.to then f:Hit(e)
 elseif e.fx=='bolt'then
  Source.Bolt({Segment=function(_,a,b,w,c,alpha,core,_,_,_,taper)Record('streak',a,b,w,c,alpha,core,taper)end},function(...)Record('glow',...)end,e,{glow={3.6,2.3,.6},core={8,6.6,3.6},inner={2.8,1.85,.5}})
 else Combat.Flare(f,e.pos,e.dir,3,.85,.26,{4.2,2.6,.7},1.3,.065);for _,x in ipairs(f.flares)do Record('actualFlare',x.base,x.tip,x.width,x.color,x.life,x.age)end end
 for _,z in ipairs(f.zaps)do Record('zap',z.a,z.b,z.age,z.life,z.width)end
 for _,b in ipairs(f.missiles.booms)do Record('boom',b.pos,b.r,b.dim,b.white,b.age,b.life)end
 -- JSON null is passed as false so sparse Lua arrays retain the normal slot.
 equal(rows,case.rows,case.name);print('PASS '..case.name)
end
print('COMBAT SOURCE '..#cases..' actual H5 golden scenarios PASS')
