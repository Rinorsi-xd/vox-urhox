"""Check real font cmap/outlines and actual scoped Lua draw calls, without GPU."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path[:0]=[str(ROOT/'.tmp/font-tooling'),str(ROOT/'.tmp/nav-python-deps')]
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
bundled=ROOT/'assets/Fonts/VoxRepairSymbols-Regular.ttf'
system=Path(os.environ.get('SystemRoot','C:/Windows'))/'Fonts/seguisym.ttf'
body=ROOT/'assets/Fonts/VoxIndustrial-Bold.otf'
provenance=json.loads((ROOT/'assets/Fonts/VoxRepairSymbols-PROVENANCE.json').read_text())
assert sha(bundled)==provenance['outputSHA256']
assert sha(ROOT/'assets/Fonts/VoxRepairSymbols-OFL.txt')==provenance['licenseSHA256']
font_records={}
for path in [bundled,system,body]:
    with TTFont(path) as font:
        cmap=font.getBestCmap();u=font['head'].unitsPerEm
        record={'family':font['name'].getDebugName(1),'hasRepair':0x271a in cmap,
                'ascent':font['hhea'].ascent/u,'descent':-font['hhea'].descent/u,
                'winAscent':font['OS/2'].usWinAscent/u,'winDescent':font['OS/2'].usWinDescent/u}
        if 0x271a in cmap:
            glyph=cmap[0x271a];record['advance']=font['hmtx'][glyph][0]/u
            record['contours']=font['glyf'][glyph].numberOfContours
            assert record['contours']>0
        if path==bundled:assert set(cmap)=={0x271a} and len(font.getGlyphOrder())==2
        font_records['Fonts/VoxRepairSymbols-Regular.ttf' if path==bundled else str(path).replace('\\','/') if path==system else 'Fonts/VoxIndustrial-Bold.otf']=record
assert font_records['Fonts/VoxIndustrial-Bold.otf']['hasRepair'] is False

lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().FontRecords=lua.table_from({name:lua.table_from(record) for name,record in font_records.items()})
lua.globals().SystemPath=str(system).replace('\\','/')
lua.globals().OldWidgetCode=subprocess.check_output(['git','show','HEAD:scripts/ui/EndlessWidgets.lua'],text=True,encoding='utf-8')
run=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local platform,systemExists='Windows',true
function GetPlatform()return platform end
local getenv=os.getenv;os.getenv=function()return SystemPath:match('^(.*)/Fonts/')end
fileSystem={FileExists=function(_,path)return systemExists and path==SystemPath end}
package.preload['core.SystemFontCollection']=function()return {}end
package.preload['core.BodyFontMetrics']=function()return {Load=function(path)return FontRecords[path]end}end
package.preload['core.ResourceData']=function()return {Read=function()return {}end}end
package.preload['ui.SourceTextLayout']=function()return {Get=function()return nil end,Metrics=function()end}end
local base={};function base:Extend()return setmetatable({},{__index=self})end
package.preload['urhox-libs/UI']=function()return {Button=base,Panel=base}end
package.preload['urhox-libs/UI/Widgets/Button']=function()return base end
local created,faces,texts,fallbacks={}, {}, {}, {}
local active,size=nil,0
function nvgCreateFont(vg,name,path)
 created[#created+1]={vg=vg,name=name,path=path};faces[name]=path;return #created
end
function nvgAddFallbackFontId(_,a,b)fallbacks[#fallbacks+1]={a,b}end
function nvgAddFallbackFont(_,a,b)fallbacks[#fallbacks+1]={a,b}end
function nvgFontFace(_,name)active=name end
function nvgFontSize(_,value)size=value end
function nvgTextBounds(_,_,_,text)return #text*size*.5 end
function nvgText(_,x,y,text)
 texts[#texts+1]={x=x,y=y,text=text,size=size,font=active,path=faces[active],
  hasGlyph=FontRecords[faces[active]] and FontRecords[faces[active]].hasRepair}
end
function nvgRGBA(...)return {...}end
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgFillColor','nvgFill','nvgStrokeColor','nvgStrokeWidth','nvgStroke',
 'nvgSave','nvgRestore','nvgGlobalAlpha','nvgTextLetterSpacing','nvgTextAlign'})do _G[name]=function()end end
NVG_ALIGN_LEFT=1;NVG_ALIGN_TOP=2;NVG_ALIGN_RIGHT=4;NVG_ALIGN_CENTER=8;NVG_ALIGN_BASELINE=16
return function(target,available,old)
 platform=target;systemExists=available
 for _,name in ipairs({'ui.SourceFonts','ui.SourceDraw','ui.EndlessWidgets'})do package.loaded[name]=nil end
 created={};faces={};texts={};fallbacks={}
 local D=require'ui.SourceDraw';local F=require'ui.SourceFonts'
 local Widgets=old and assert(load(OldWidgetCode))() or require'ui.EndlessWidgets'
 local button=setmetatable({props={repair=true,text='repair',subtitle='supply'},state={},
  GetAbsoluteLayout=function()return {x=100,y=200,w=300,h=180}end},{__index=Widgets.Button})
 local vg={};button:Render(vg);button:Render(vg)
 local face=F.ResolveRepairSymbol();assert(face==F.ResolveRepairSymbol(),'resolved face reused')
 local checks=0;local iconCalls=0
 for _,call in ipairs(texts)do
  if call.text=='✚'then
   assert(call.x==120 and call.y==212 and call.size==44,'original position and size unchanged');checks=checks+1
   if not old then assert(call.font=='vox-repair-symbol' and call.hasGlyph,'real selected cmap must include U271A');checks=checks+1 end
   iconCalls=iconCalls+1
  else assert(call.font=='vox-title','text face unchanged');checks=checks+1 end
 end
 local loads=0;for _,call in ipairs(created)do if call.name=='vox-repair-symbol'then loads=loads+1;assert(call.path==face.path);checks=checks+1 end end
 if not old then assert(loads==1,'one lazy load per context');checks=checks+1 end
 for _,pair in ipairs(fallbacks)do assert(pair[1]~='vox-repair-symbol' and pair[2]~='vox-repair-symbol','no global fallback changes')end
 D.Width(vg,'123',20,'vox-display');assert(faces['vox-display']=='Fonts/BarlowCondensed-BoldItalic.ttf');checks=checks+1
 if not old then
  D.Begin({});local count=#created;assert(created[count].name~='vox-repair-symbol','begin stays lazy');checks=checks+1
  local other={};D.Begin(other);D.Text(other,'✚',0,0,44,nil,'vox-repair-symbol');assert(created[#created].name=='vox-repair-symbol');checks=checks+1
 end
 assert(iconCalls==2);checks=checks+1
 return face.path,checks,old and texts[1] or nil,texts
end
''')
checks=6
scenarios=[]
for platform,exists in [('Windows',True),('Windows',False),('Web',True),('Android',True),('iOS',True),('Mac OS X',True)]:
    selected,count,_,_=run(platform,exists,False)
    expected=str(system).replace('\\','/') if platform=='Windows' and exists else 'Fonts/VoxRepairSymbols-Regular.ttf'
    assert selected==expected,(platform,selected,expected)
    checks+=count+1
    scenarios.append({'platform':platform,'systemFontExists':exists,'selected':selected})
_,_,_,old_calls=run('Web',False,True)
old_icon=next(call for _,call in old_calls.items() if call['text']=='✚')
assert old_icon['font']=='vox-title' and old_icon['hasGlyph'] is False
checks+=1
paths=['scripts/ui/EndlessWidgets.lua','scripts/ui/ActionButton.lua','scripts/ui/SourceFonts.lua','scripts/ui/SourceDraw.lua',
       'assets/Fonts/VoxRepairSymbols-Regular.ttf','assets/Fonts/VoxRepairSymbols-OFL.txt','assets/Fonts/VoxRepairSymbols-PROVENANCE.json']
report={'pass':True,'checks':checks,'scenarios':scenarios,'fonts':font_records,'oldActualWidget':{'face':old_icon['font'],'glyphPresent':old_icon['hasGlyph']},
        'production':{p:sha(ROOT/p) for p in paths},'subsetBytes':bundled.stat().st_size,
        'boundary':'Actual Lua EndlessWidgets/SourceDraw/SourceFonts with native UI/draw adapters; actual fontTools cmap/outline checks. No GPU/render acceptance; Web/mobile Noto substitute is not pixel-identical Segoe UI Symbol. Windows system face is referenced locally, never copied.'}
output=ROOT/'docs/migration/evidence/repair-symbol-offline.json'
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
