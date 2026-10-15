local fixture=nil ---@type table|nil
local hud=nil ---@type table|nil
local boss=nil ---@type table|nil
local state=nil ---@type table|nil
local Motion=require 'ui.BossHudMotion'
local function Near(a,b) return math.abs(a-b)<.00003 end
V.atFrame(43,function()
    local file=assert(io.open('tools/migration/source-boss-hud-fixtures.json'));fixture=cjson.decode(file:read('*a'));file:close()
    local motion=Motion.New();local previous=0
    Motion.Update(motion,0,{hp=.4,shown=true,cinematic=true,kneel=true,ult=3})
    for i,want in ipairs(fixture.samples) do
        Motion.Update(motion,want.time-previous,{hp=.4,shown=true,cinematic=true,kneel=true,ult=3});previous=want.time
        for _,key in ipairs({'main','trail','bar','letter','prompt','kneel'}) do V.assert(Near(motion[key].value,want[key]),'frozen Boss CSS '..key..' sample '..i) end
        V.assert(Near(Motion.Boom(want.time),want.boom),'frozen .9 second ease-out white flash '..i)
    end
    local fresh=Motion.New();Motion.Update(fresh,0,{hp=.4});Motion.Update(fresh,.2,{hp=.4})
    V.assert(fresh.main.value==.4 and fresh.trail.value==1,'source main finishes before delayed damage trail begins')
    Motion.Update(fresh,.04,{hp=.2});V.assert(fresh.trail.value==1,'new damage restarts source delayed trail transition')
    V.assert(Near(Motion.Blink(0),1) and Near(Motion.Blink(.125),.675) and Near(Motion.Blink(.25),.35) and Near(Motion.Blink(.375),.675),'source steps-two kneel blink preserves four keyframe plateaus')
    local app=VOX_HANGAR.app;app.loadingFlow:Close();app.Update=function()end;app.PostUpdate=function()end
    if app.tutorial then app.tutorial:Dispose();app.tutorial=nil end
    local UI=require 'urhox-libs/UI';local root=UI.Panel{width='100%',height='100%',backgroundColor={10,14,20,255}};UI.SetRoot(root,true)
    state={hp=.4,state='fight',phase=2,cinematic=false,kneel=false,kneelK=0,nodes={{broken=false},{broken=false},{broken=false},{broken=false}},stagger=0}
    boss={time=0,rules={config={chip={.45,.55,.65,.8,1}}},mission={player={Position=function()return {0,0,0}end}},UnderRoof=function()return true end,Snapshot=function()return state end}
    hud=require('ui.BossHud').Attach({story={boss=boss}},root);hud.Update(0);hud.Update(.5)
end)
V.atFrame(46,function()
    local image=Image:new();graphics:TakeScreenShot(image);local red=0
    for y=math.floor(image.height*.015),math.floor(image.height*.11),2 do for x=math.floor(image.width*.25),math.floor(image.width*.75),2 do
        local c=image:GetPixel(x,y);if c.r>.4 and c.g<.4 and c.b<.5 then red=red+1 end
    end end
    V.assert(red>40,'actual Boss HUD renders main and delayed trail source damage bars')
    image:SavePNG('docs/migration/evidence/boss-hud-damage-native.png');image:Dispose()
    state.cinematic=true;hud.Update(0);hud.Update(.25)
end)
V.atFrame(49,function()
    V.assert(hud.layer.motion.letter.value>.9 and hud.layer.motion.prompt.value==0,'actual cinematic black bars animate before source delayed Enter hint')
    local image=Image:new();graphics:TakeScreenShot(image);local top=image:GetPixel(math.floor(image.width*.5),math.floor(image.height*.03))
    V.assert(top.r<.01 and top.g<.01 and top.b<.01,'actual animated cinematic top letterbox renders opaque black')
    image:SavePNG('docs/migration/evidence/boss-hud-letter-native.png');image:Dispose()
    hud.Update(.5);V.assert(hud.layer.motion.prompt.value>0,'source Enter prompt begins only after six tenths delay')
    state.cinematic=false;state.ult=3;hud.Update(0);hud.Update(.75);boss.ultFlash=0;boss.time=.45
end)
V.atFrame(52,function()
    local image=Image:new();graphics:TakeScreenShot(image);image:SavePNG('docs/migration/evidence/boss-hud-ult-native.png');image:Dispose()
    V.assert(hud.layer.motion.letter.value==0 and hud.layer.motion.ult.value==1,'actual source ult and cinematic opacity remain independent')
    hud.Dispose();hud.Dispose();V.assert(hud.layer.parent==nil,'Boss HUD detaches idempotently after animated states');V.finish()
end)
