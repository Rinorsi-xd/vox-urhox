-- Actual Lua 5.4 weak values/finalizers, production module and old hotspot.
local checks={};local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
local realGC=collectgarbage
local function Module(source,gc)
 local env=setmetatable({collectgarbage=gc},{__index=_G})
 local cycle=assert(load(COLLECTION,'CollectionCycle','t',env))()
 env.require=function(name)if name=='core.CollectionCycle'then return cycle end;return require(name)end
 return assert(load(source,'RenderTargetLifetime','t',env))()
end
local function Hotspot(source)
 local calls={collect=0,step=0};local held={SetNumViewports=function()end}
 local texture={GetRenderSurface=function()return held end,Dispose=function()error('borrowed parent must remain alive')end}
 local mode='generational'
 local lifetime=Module(source,function(kind)
  calls[kind]=(calls[kind]or 0)+1
  if kind=='incremental'or kind=='generational'then local previous=mode;mode=kind;return previous end
  return false
 end)
 lifetime.Retire(texture);for _=1,60 do lifetime.Update()end
 check(lifetime.PendingCount()==1,'external borrower keeps texture pending throughout sixty updates')
 return calls
end
local old=Hotspot(HISTORICAL);local current=Hotspot(PRODUCTION)
check(old.collect==20 and old.step==0,'old production performs twenty complete heap collections in sixty frames')
check(current.collect==0 and current.step==20,'new background performs twenty bounded requests and zero forced full collections')
local textureCount,finalizedCount=0,0
local function Factory()
 local surfaces=setmetatable({},{__mode='v'});local finalized={};local disposed={};local nilBeforeFinalizer=0;local gets=0
 local function New()
  textureCount=textureCount+1;local id=textureCount;local texture={alive=true,id=id}
  function texture:GetRenderSurface()gets=gets+1;return surfaces[id]end
  function texture:Dispose()
   check(self.alive,'texture '..id..' releases exactly once')
   check(finalized[id]==true,'surface '..id..' finalizes before parent texture disposal')
   self.alive=false;disposed[id]=true
  end
  local surface=setmetatable({parent=texture,viewports=1},{__gc=function(self)
   check(texture.alive,'raw parent '..id..' stays alive during surface finalizer')
   if surfaces[id]==nil then nilBeforeFinalizer=nilBeforeFinalizer+1 end
   finalized[id]=true;finalizedCount=finalizedCount+1
  end})
  function surface:SetNumViewports(n)self.viewports=n end
  surfaces[id]=surface;return texture,surface
 end
 return New,disposed,function()return nilBeforeFinalizer,gets end
end
local modes={}
for _,mode in ipairs({'incremental','generational'})do
 realGC(mode);realGC('collect');realGC('stop')
 local calls={collect=0,step=0};local completed=0
 local lifetime=Module(PRODUCTION,function(kind,size)
  calls[kind]=(calls[kind]or 0)+1;local result=realGC(kind,size)
  if kind=='step'and result then completed=completed+1 end
  return result
 end)
 local New,disposed,stats=Factory();local textures,borrowers={},{}
 for i=1,80 do textures[i],borrowers[i]=New();lifetime.Retire(textures[i]);check(borrowers[i].viewports==0,'retirement detaches every render viewport '..mode..'/'..i)end
 lifetime.Retire(textures[1]);check(select(2,stats())==80,'duplicate retirement does not borrow a second wrapper '..mode)
 for _=1,60 do lifetime.Update()end
 check(calls.collect==0 and lifetime.PendingCount()==80,'held surfaces remain pending with no full collection '..mode)
 for _,texture in ipairs(textures)do check(texture.alive,'externally held surface keeps parent alive '..mode)end
 -- Leave one real external borrower alive while all others become collectible.
 local held=borrowers[1];borrowers=nil
 local frames=0
 repeat lifetime.Update();frames=frames+1 until lifetime.PendingCount()==1 or frames>=600
 check(textures[1].alive and not disposed[textures[1].id],'held native parent survives other surfaces retiring '..mode)
 check(lifetime.PendingCount()==1 and completed>0,'completed shared cycle drains released surfaces in background '..mode)
 local beforeFlush=lifetime.PendingCount();lifetime.Flush()
 check(lifetime.PendingCount()==1 and textures[1].alive,'explicit Flush also preserves external borrower '..mode)
 check(calls.collect==1,'explicit Flush performs one synchronous complete collection '..mode)
 held=nil;lifetime.Flush()
 check(lifetime.PendingCount()==0,'explicit Flush drains after final external borrower releases '..mode)
 check(calls.collect==2,'second nonempty Flush retains synchronous semantics '..mode)
 lifetime.Flush();for _=1,9 do lifetime.Update()end
 check(calls.collect==2,'empty pending set performs no complete collection '..mode)
 local nilBefore=stats();check(nilBefore==80,'actual weak wrapper values clear before their finalizers '..mode)
 modes[#modes+1]={mode=mode,frames=frames,cycles=completed,pendingBeforeFlush=beforeFlush,weakNilAtFinalizer=nilBefore,calls=calls}
end
-- Even a nil weak entry is not scanned until the step reports completion.
realGC('incremental');realGC('collect');realGC('stop')
local allowComplete=false;local partial=Module(PRODUCTION,function(kind,size)
 if kind=='step'then realGC('step',size);return allowComplete end
 return realGC(kind,size)
end)
local New,disposed=Factory();local texture,surface=New();partial.Retire(texture);surface=nil;realGC('collect')
for _=1,9 do partial.Update()end
check(texture.alive and partial.PendingCount()==1,'nil weak entry remains protected while completion flag is false')
allowComplete=true;for _=1,3 do partial.Update()end
check(not texture.alive and partial.PendingCount()==0,'nil weak entry releases only after confirmed complete cycle')
local calls=0;local direct=Module(PRODUCTION,function()error('no collection needed without a surface')end)
direct.Retire(nil);direct.Retire({GetRenderSurface=function()return nil end,Dispose=function()calls=calls+1 end})
check(calls==1 and direct.PendingCount()==0,'texture without borrowed surface still disposes immediately')
realGC('restart')
return {count=#checks,checks=checks,modes=modes,historical=old,current=current,textureCount=textureCount,finalizedCount=finalizedCount}
