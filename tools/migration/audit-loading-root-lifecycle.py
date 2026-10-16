"""Replay actual UI render guard and app/loading lifecycle without a GPU."""
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
paths = ['scripts/app/HangarApp.lua', 'scripts/app/LoadingFlow.lua',
         'scripts/ui/LoadingPage.lua', 'urhox-libs/UI/Core/UI.lua',
         'scripts/ui/BuildHud.lua', 'scripts/ui/DriveHud.lua', 'scripts/ui/GarageHud.lua']
app_source, flow_source, page_source, ui_source, build_source, drive_source, garage_source = [(ROOT / p).read_text(encoding='utf-8') for p in paths]
release = app_source[app_source.index('function App:ReleaseMapHangar()'):app_source.index('function App:ReleaseSettledAssets()')]
set_root = ui_source[ui_source.index('function UI.SetRoot(widget, destroyOld)'):ui_source.index('--- Get the root widget')]
render = ui_source[ui_source.index('function UI.Render()'):ui_source.index('--- Queue a render callback')]
page_render = page_source[page_source.index('function Page:Render(vg)'):page_source.index('function Page:Dispose()')]
build_dispose = build_source[build_source.index('    function state.Dispose()'):build_source.index('    function state.ViewState()')]
drive_install = drive_source[drive_source.index('    UI.SetRoot(root,true);state.Update(session,0);return state'):drive_source.rindex('\nend')]
garage_install = garage_source[garage_source.index('    Layout.Apply(s,w,h,UI.GetSafeAreaInsets());UI.SetRoot(s.root,true)'):garage_source.index('\nend\nfunction M.Create(app)')]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
package.path='scripts/?.lua;'..package.path
UI={};local function Noop()end
UI.Panel=function(props)return {props=props,node=true,Destroy=function(self)self.destroyed=true end}end
UI.GetViewportSize=function()return 1920,1080 end
UI.GetSafeAreaInsets=function()return {left=0,right=0,top=0,bottom=0}end
UI.GetFocus=function()return nil end
UI.ClearFocus=Noop
package.loaded['urhox-libs/UI']=UI
package.loaded['ui.BootLoading']={Draw=Noop}
package.loaded['ui.LiveryPage']={Leave=Noop}
package.loaded['ui.VoxTheme']={TrimThumbnails=Noop}
graphics={width=1920,height=1080}
for _,name in ipairs({'nvgBeginFrame','nvgEndFrame','nvgSave','nvgRestore','nvgScale','nvgScissor','nvgGlobalAlpha'})do _G[name]=Noop end
''')
lua.execute(r'''
local root_;local nvg_=true;local enabled_=true;local layoutDirty_=false
local fixedWidgets_={};local overlayQueue_={};local globalComponents_={}
local scale_=1;local saveDepth_=0;local inspectorRoot_;local inspectorRenderHook_
local screenWidth_,screenHeight_=1920,1080
local function renderWidgetTree()end
UI.Layout=function()layoutDirty_=false end
UI.GetRoot=function()return root_ end
UI.Register=function(widget)globalComponents_.loading=widget end
''' + set_root + render)
lua.execute(r'''
local Page={};local D={Begin=function()end}
''' + page_render + r'''
actualPage=setmetatable({DrawTransition=function()end,DrawPage=function()end},{__index=Page})
local App={};local Hud={GetState=function()return false end,Dispose=function()UI.SetRoot(nil)end}
''' + release + r'''
local Flow=require 'app.LoadingFlow'
flow=setmetatable({active=true,pageVisible=true,phase='loading',pageFrames=0,map={boot=true}},{__index=Flow})
actualPage.owner=flow;UI.Register(actualPage)
local function Owned()return {Dispose=function(self)self.disposed=true end}end
app=setmetatable({scene=Owned(),hangar=Owned(),previews=Owned(),camera={},DetachSceneRender=function()end,
 DeferAssetRelease=function(self,done)self.pendingAssetRelease=done end},{__index=App})
''')
lua.execute(r'''
function InstallOldBuildHud()
    local root=UI.Panel{width='100%',height='100%'}
    local state={selectionBar={Dispose=function(self)self.disposed=true end}};local controls={Cancel=function()end};local name={}
''' + build_dispose + r'''
    UI.SetRoot(root);app.build={Dispose=function()state.Dispose()end}
    return root,state
end
function InstallDriveHudRoot()
    local root=UI.Panel{width='100%',height='100%',pointerEvents='box-none'}
    local state={root=root,Update=function()end};local session={}
''' + drive_install + r'''
end
function InstallGarageHudRoot()
    local s={root=UI.Panel{width='100%',height='100%'}}
    local w,h=1920,1080;local Layout={Apply=function()end}
''' + garage_install + r'''
    return s.root
end
''')
result = lua.execute(r'''
local checks=0
local function Check(value,label)checks=checks+1;assert(value,label)end
UI.SetRoot(nil);UI.Render();flow:FramePresented()
Check(flow.pageFrames==0,'actual UI.Render guard reproduces rootless overlay starvation')
local oldBuild,oldBuildState=InstallOldBuildHud()
local old=app.scene;app:ReleaseMapHangar()
Check(old.disposed and app.scene==nil and app.hangar==nil and app.camera==nil,'actual hall release clears native ownership')
local placeholder=UI.GetRoot()
Check(placeholder and placeholder.props.width=='100%' and placeholder.props.height=='100%' and placeholder.props.pointerEvents=='none','actual release keeps only a noninteractive fullscreen root')
Check(oldBuild.destroyed and oldBuildState.disposed and oldBuildState.selectionBar.disposed and app.build==nil and UI.GetRoot()==placeholder,'actual late BuildHud.Dispose destroys only old HUD and owned selection bar and preserves loading placeholder')
oldBuildState.Dispose();Check(UI.GetRoot()==placeholder,'repeated old build disposal cannot clear loading root')
Check(_G.VOX_HANGAR==nil,'no fake live scene global is restored')
UI.Render();flow:FramePresented();Check(flow.pageFrames==1,'actual root enables global LoadingPage Render and first presentation')
UI.Render();flow:FramePresented();Check(flow.pageFrames==2 and flow:CanStartLoad(),'actual boot loader gate receives presented frames')
local Transition=require 'app.WebMapTransition';local swept=0
local t=Transition.New(function()end,function()swept=swept+1 end)
local token=t:Begin(true);t:CanStart(true,2,true);t:Cancel(token);t:BeginRecovery();t:PrepareRecovery()
Check(not t:CanStart(flow:CanStartLoad(),flow.pageFrames,true),'actual recovery fence begins after loading page presents')
for _=1,3 do UI.Render();flow:FramePresented()end
Check(t:CanStart(flow:CanStartLoad(),flow.pageFrames,true) and swept==1,'actual recovery fence completes after three additional rendered frames')
local replacement=InstallDriveHudRoot()
Check(placeholder.destroyed and UI.GetRoot()==replacement.root,'actual DriveHud install destroys placeholder and takes over input root')
flow.active=false;UI.Render();flow:FramePresented()
Check(flow.pageFrames==5,'closed overlay cannot create false presented frames')
app.scene={Dispose=function()end};app.hangar={Dispose=function()end};app.previews={Dispose=function()end}
app:ReleaseMapHangar();local recoveryPlaceholder=UI.GetRoot()
local recoveryRoot=InstallGarageHudRoot()
Check(recoveryPlaceholder.destroyed and UI.GetRoot()==recoveryRoot,'actual recovered GarageHud install destroys recovery placeholder and takes over root')
return {pass=true,checks=checks}
''')
report = dict(result)
report['sha256'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
report['boundary'] = 'Actual extracted UI.SetRoot/UI.Render, ReleaseMapHangar, LoadingPage.Render, BuildHud.Dispose, DriveHud/GarageHud root installation statements, LoadingFlow and WebMapTransition; native/drawing doubles and simplified HUD construction, no GPU/browser acceptance.'
out = ROOT / 'docs/migration/evidence/loading-root-lifecycle-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
