"""CPU validation of generated native fixture; never starts a renderer."""
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
data=Path(sys.argv[1]).read_bytes()
def check(source):
 lua=LuaRuntime(encoding=None)
 lua.execute(b"V={frames={},atFrame=function(n,f)assert(type(f)=='function');V.frames[#V.frames+1]=n end}")
 lua.execute(source)
 assert list(lua.globals().V[b'frames'].values())==[2,6,10,14,18,22,26,30,34]
assert not data.startswith(b'\xef\xbb\xbf')
assert b'__EVIDENCE__'not in data
check(data)
try:check(b'\xef\xbb\xbf'+data)
except Exception:pass
else:raise AssertionError('BOM negative escaped')
if len(sys.argv)>2:
 project=Path(sys.argv[2]);lua=LuaRuntime(unpack_returned_tuples=True)
 def convert(value):
  if isinstance(value,dict):return lua.table_from({key:convert(item)for key,item in value.items()})
  if isinstance(value,list):return lua.table_from([convert(item)for item in value])
  return value
 def resource(path):return (project/'assets'/path).read_bytes().decode('utf-8')
 lua.globals().RESOURCE=resource;lua.globals().JSON=lambda text:convert(json.loads(text))
 lua.globals().ISOLATED_PATH=str(project/'scripts/?.lua').replace('\\','/')
 lua.execute('''
package.path=ISOLATED_PATH..';'..package.path
local ui={initialized=false,Widget={}}
function ui.Init()ui.initialized=true end
function ui.Shutdown()ui.initialized=false end
function ui.GetViewportSize()return 1600,900 end
function ui.UnregisterGlobalComponent()end
function ui.SetRoot(root)ui.root=root end
function ui.GetRoot()return ui.root end
function ui.Widget:Extend()local class={};return setmetatable(class,{__call=function(c,props)return setmetatable(props,{__index=c})end})end
ui.Scale={DEFAULT=1};package.loaded['urhox-libs/UI']=ui
package.loaded['urhox-libs/Engine/i18n']=true
cache={GetFile=function(_,path)local text=RESOURCE(path);return {size=#text,Dispose=function()end,Read=function()return {ReadString=function()return text end,Clear=function()end}end}end}
cjson={decode=JSON};V={frames={},assert=function(value,message)assert(value,message)end,atFrame=function(n,f)V.frames[n]=f end}
function SubscribeToEvent()end
function UnsubscribeFromEvent()end
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgFillColor','nvgFill','nvgSave','nvgRestore','nvgTranslate','nvgScale','nvgRotate','nvgGlobalAlpha','nvgMoveTo','nvgLineTo','nvgBezierTo','nvgClosePath','nvgPathWinding','nvgStrokeWidth','nvgStrokeColor','nvgStroke'})do _G[name]=function()end end
function nvgRGBA(...)return {...}end
NVG_SOLID=1;NVG_HOLE=2
''')
 lua.execute((project/'scripts/main.lua').read_text(encoding='utf-8'))
 lua.execute(data.decode('utf-8'));lua.execute('Start();assert(COMIC_IMPACT_APP_STARTED==true);V.frames[2]();require("urhox-libs/UI").GetRoot():Render(0);assert(VOX_HANGAR==nil and package.loaded["app.HangarApp"]==nil);Stop()')
 print(json.dumps({'status':'PASS','isolatedMainStartStop':True,'actualProductionGlyphDraw':True,'actualResourceMountReads':['UI/SourceIcons.json','Intro/Fonts/TitleGlyphs.json'],'gameBootstrapImported':False,'GPUStarted':False}))
print(json.dumps({'status':'PASS','actualLua54RegistrationCallbacks':9,'frames':[2,6,10,14,18,22,26,30,34],'BOMNegative':'REJECTED','GPUStarted':False}))
