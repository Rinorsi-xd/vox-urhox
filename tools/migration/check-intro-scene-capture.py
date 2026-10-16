"""Exercise the production GPU capture ownership with controlled native adapters."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
result = lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local count=0
local function check(ok,label)assert(ok,label);count=count+1 end
local retired={}
package.loaded['render.RenderTargetLifetime']={Retire=function(t)
 check(t.surface.views==0,'detach viewports before deferred retirement')
 check(not retired[t],'texture retires once');retired[t]=true
end}
TEXTURE_RENDERTARGET=9;SURFACE_MANUALUPDATE=7;FILTER_BILINEAR=2
graphics={GetWidth=function()return 2400 end,GetHeight=function()return 1080 end}
Graphics={GetRGBAFormat=function()return 4 end}
renderer={GetDefaultRenderPath=function()return{Clone=function()return{}end}end}
local fail=false;local textures={}
Texture2D={new=function()
 local surface={views=0,queued=0,SetViewport=function(s,_,v)s.views=1;s.viewport=v end,
  SetNumViewports=function(s,n)s.views=n end,SetUpdateMode=function(s,m)s.mode=m end,
  QueueUpdate=function(s)s.queued=s.queued+1 end}
 local t={surface=surface,SetNumLevels=function(s,n)s.levels=n end,
  SetSize=function(s,w,h,format,usage)s.w=w;s.h=h;s.usage=usage;return not fail end,
  SetFilterMode=function(s,m)s.filter=m end,GetRenderSurface=function()return surface end}
 textures[#textures+1]=t;return t
end}
Viewport={new=function(_,scene,camera)return{scene=scene,camera=camera,SetRenderPath=function(s,p)s.path=p end}end}
local nodes={}
local scene={CreateChild=function(_,name)
 local n={name=name,Dispose=function(s)check(not s.disposed,'camera node releases once');s.disposed=true end,
  CreateComponent=function(_,kind)check(kind=='Camera','capture creates only a camera');return{}end}
 nodes[#nodes+1]=n;return n
end}
local camera={node={worldPosition={x=-4,y=1.6,z=-34},worldRotation={w=1}},fov=56,nearClip=.1,farClip=800}
local Capture=require 'intro.IntroSceneCapture'
local c=Capture.New(scene,camera);local t=c.texture
check(t.w==1280 and t.h==576,'capture keeps landscape20:9 aspect and bounded texture size')
check(c.node.position==camera.node.worldPosition and c.node.rotation==camera.node.worldRotation,'copy original camera world pose')
check(c.camera.fov==56 and c.camera.aspectRatio==1280/576,'source lens and capture aspect')
check(t.levels==1 and t.usage==TEXTURE_RENDERTARGET,'single-level GPU render target')
check(t.surface.mode==SURFACE_MANUALUPDATE and t.surface.queued==1,'manual render queued at construction')
check(not c:Presented() and not c:Presented(),'retain source three presented frames')
check(c:Presented() and c.ready and c.texture==t,'freeze the third frame without CPU readback')
check(t.surface.views==0 and c.node==nil and c.viewport==nil,'frozen texture has no live scene/camera viewport')
check(c:Presented() and t.surface.queued==3,'finished capture never requeues rendering')
c:Dispose();c:Dispose();check(retired[t],'completed capture uses safe render-target retirement')
local cancel=Capture.New(scene,camera);local ct=cancel.texture;cancel:Dispose()
check(retired[ct] and not cancel:Presented(),'cancel stops capture and retires its texture')
fail=true
local ok=pcall(Capture.New,scene,camera)
check(not ok and retired[textures[#textures]] and nodes[#nodes].disposed,'allocation failure cleans partial native owners')
return {checks=count,result='PASS'}
''')
report = {key: value for key, value in result.items()}
report['productionHashes'] = {path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in [
    'scripts/intro/IntroSceneCapture.lua', 'scripts/app/OpeningHost.lua']}
report['boundary'] = 'Actual Lua capture creation, lens, three-frame freeze, cancellation, repeated disposal and allocation failure; native adapters only. Rendered content and GPU completion require browser verification.'
output = ROOT/'docs/migration/evidence/intro-scene-capture-offline.json'
output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
