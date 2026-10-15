-- Exercises the real LoadingFlow lifecycle without creating an engine/browser.
package.path='scripts/?.lua;scripts/?/init.lua;'..package.path
local function eq(a,b,label)assert(a==b,(label or 'equality')..': '..tostring(a)..' ~= '..tostring(b))end
package.loaded['urhox-libs/UI']={}
package.loaded['urhox-libs/UI/Core/ImageCache']={Release=function()end}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function()return true end}
package.loaded['app.ResourceGate']={New=function()return {Start=function(_,_,cb)cb(true)end,Cancel=function()end}end}
package.loaded['ui.LoadingPage']={New=function()return {Open=function()end,Close=function()end,Dispose=function()end}end}
Time={GetSystemTime=function()return 5 end};renderer={GetViewport=function()return {camera={}}end}
local counters={new=0,presented=0,dispose=0,restore=0};local failure
package.loaded['render.SceneWarmup']={New=function()return {items={1},skipped=0,batches=1,
 Rendered=function()return true end,Restore=function()counters.restore=counters.restore+1 end}end}
package.loaded['render.CombatWarmup']={New=function()
 counters.new=counters.new+1;if failure=='new'then error('new failed')end
 local w={calls=0};function w:Presented()counters.presented=counters.presented+1;if failure=='presented'then error('presented failed')end;self.calls=self.calls+1;return self.calls>=2 end
 function w:Dispose()counters.dispose=counters.dispose+1 end;return w
end}
local Flow=require'app.LoadingFlow'
local function fresh(boot)
 counters={new=0,presented=0,dispose=0,restore=0};failure=nil
 local app={scene={},trial=not boot and {disposed=false}or nil,graphicsSettings={SetSceneVisible=function()end}}
 local f=Flow.New(app);f:Open({id=boot and 'boot'or 'trial',boot=boot});f:Finish();return f
end
local checks=0
do
 local f=fresh(false);f:Rendered();eq(counters.new,0,'scene warmup must finish first');f:Rendered();eq(counters.new,1,'one combat warmup')
 eq(f.warmFrames,0,'no reveal before effects');f:Rendered();eq(f.warmFrames,0,'no reveal before presented completion')
 f:Rendered();eq(f.warmFrames,0,'completion frame remains covered');for _=1,6 do f:Rendered()end
 eq(counters.new,1,'repeated rendered must not reinitialize');eq(f.warmFrames,6,'warmFrames resumes after combat');f:Close();checks=checks+1
end
do
 local f=fresh(true);for _=1,5 do f:Rendered()end;eq(counters.new,0,'boot never constructs combat warmer');eq(f.warmFrames,4,'boot normal warmFrames');f:Close();checks=checks+1
end
do
 local f=fresh(false);f:Rendered();f:Close();f:Rendered();eq(counters.new,0,'close cancels pending');eq(f.combatWarmupPending,false);checks=checks+1
end
do
 local f=fresh(false);f:Rendered();f:Rendered();f:Close();eq(counters.dispose,1,'close disposes active warmer');eq(f.combatWarmup,nil)
 f:Rendered();eq(counters.new,1,'closed flow stays closed');eq(counters.presented,0,'closed flow does not present');checks=checks+1
end
do
 local f=fresh(false);f:Rendered();failure='new';f:Rendered();eq(f.failed,true,'new error reaches loading failure');eq(f.combatWarmupPending,false)
 f:Rendered();eq(counters.new,1,'failed init never loops');eq(f.warmFrames,0);f:Close();checks=checks+1
end
do
 local f=fresh(false);f:Rendered();f:Rendered();failure='presented';f:Rendered();eq(f.failed,true,'presented error reaches loading failure')
 eq(counters.dispose,1,'presented failure releases warmer');eq(f.combatWarmup,nil);f:Rendered();eq(counters.presented,1,'failed warmup stops');f:Close();checks=checks+1
end
do
 local f=fresh(false);f:Fail('cancel while scene warmer exists');eq(counters.restore,1,'failure restores scene masks');eq(f.renderWarmup,nil)
 f:Rendered();eq(counters.new,0,'failed scene warmup never starts combat');f:Close();checks=checks+1
end
print('LoadingFlow combat warmup lifecycle: '..checks..' scenarios PASS')
