local UI=require 'urhox-libs/UI'
local Readouts=require 'ui.DriveReadouts'
local Trial=require 'app.TrialSession'
local state,panel
V.atFrame(2,function()
    local paths=require('ui.SourceFonts').Resolve()
    UI.Init({theme='default-dark',scale=UI.Scale.DPR,fonts={{family='sans',weights={normal=paths.body,bold=paths.bold}}}})
    local f=File('tools/migration/source-drive-readouts.json',FILE_READ);local fixtures=cjson.decode(f:ReadString());f:Dispose()
    for i,case in ipairs(fixtures.cases) do
        local t=case.tel;if t.hoverHeight==cjson.null then t.hoverHeight=nil end;if t.mechJetFuel==cjson.null then t.mechJetFuel=nil end
        local alert,summary=require('ui.DriveReadout').Summary(t)
        V.assert(alert==case.alert and summary==case.state,'actual frozen summary '..i)
    end
    local v={spec={motion={topSpeed=20,thrusterSpeed=25,L=.8,mass=1350,load=2000},rotors={},thrusters={},boxes={},hulls={},hovers={}},telemetry={speed=12,totalSpeed=14,contact=4},speed=12,com={0,1.2,0},wheels={}}
    state={vehicle=v,weapons={groups={{}}},details=true,pointer={captured=true},map={name='试车场'},name='字体与详情测试车'}
    local root=UI.Panel{width='100%',height='100%',pointerEvents='box-none'}
    local details=require('ui.DriveDetails'){visible=false};details.session=state;details:Refresh()
    panel=Readouts.New(state,root,details);panel:Refresh();panel:Tick(.1,false);UI.SetRoot(root)
    for _,s in ipairs({{1920,1080,false},{2520,1134,false},{840,378,true}}) do
        local g=Readouts.Viewport(s[1],s[2],s[1],s[2],s[3]);V.assert(g.w*g.k==s[1] and math.abs(g.h*g.k-s[2])<.01,'viewport preserves landscape geometry')
    end
end)
V.atFrame(6,function()
    V.assert(panel.expandedRect and panel.expandedRect.y>0 and panel.toggleRect,'source two-column panel and toggle rendered')
    V.assert(not panel.details:IsVisible(),'legacy floating detail surface hidden')
    panel.maxScroll=400;panel:ScrollDetails(300);V.assert(panel.scroll==300,'details scroll advances')
    panel:ScrollDetails(1000);V.assert(panel.scroll==400,'details scroll clamps bottom')
    panel:ScrollDetails(-1000);V.assert(panel.scroll==0,'details scroll clamps top')
    panel:OnWheel(0,-1);V.assert(panel.scroll==0,'PC UI wheel does not double consume TrialSession wheel')
    local r=panel.expandedRect;local k=panel.geometry.k;local y=(r.y+20)*k
    panel:OnPointerDown({x=(r.x+20)*k,y=y,pointerId=5});panel:OnPointerMove({x=0,y=y-70*k,pointerId=6})
    V.assert(panel.scroll==0,'foreign pointer cannot move details drag')
    panel:OnPointerUp({pointerId=6});panel:OnPointerMove({x=0,y=y-70*k,pointerId=5})
    V.assert(panel.scroll==70,'owner retains drag across foreign pointer release');panel:OnPointerCancel({pointerId=5})
    panel:Toggle();V.assert(not state.details,'details toggle closes actual session state');panel:Toggle()
    local camera={};camera.details=true;camera.hud={readouts=panel};setmetatable(camera,{__index=Trial})
    camera:Zoom(-1);V.assert(panel.scroll==170,'production wheel route scrolls detail once')
    camera.chase={dist=10,zoom=1};camera.chase.Zoom=function(self,delta) self.zoom=self.zoom*1.0012^delta end
    camera:ZoomPixels(100);V.assert(panel.scroll==170 and camera.cameraDistance>10,'touch pinch remains camera zoom while details are open')
    local image=Image();V.assert(graphics:TakeScreenShot(image),'capture actual detail renderer');image:SavePNG('docs/migration/evidence/drive-readouts-native-pc.png');image:Dispose()
    state.touch=true
end)
V.atFrame(9,function() V.assert(panel.toggleRect==nil,'source touch CSS hides desktop keyboard shortcut strip');V.finish() end)
