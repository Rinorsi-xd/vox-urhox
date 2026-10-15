"""Execute frozen H5 detail rows against actual Lua, plus real Render font commands."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

os.chdir(ROOT)
golden = json.loads(subprocess.check_output(['node', 'tools/migration/source-inventory-detail-golden.cjs'], encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")

def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value

build = lua.eval("require('ui.InventoryDetailRows').Build")
checks = 0
for case in golden['cases']:
    actual = build(convert(case['def']), convert(case['ws']))
    assert len(actual) == len(case['expected']), (case['id'], 'row count')
    checks += 1
    for index, expected in enumerate(case['expected'], 1):
        for column, value in enumerate(expected, 1):
            assert actual[index][column] == value, (case['id'], index, column, actual[index][column], value)
            checks += 1

lua.globals().CATALOG = convert(golden['cases'])
lua.execute('''
local defs={LIST={},PARTS={},CATEGORIES={}}
for _,case in ipairs(CATALOG) do defs.LIST[#defs.LIST+1]=case.def;defs.PARTS[case.id]=case.def end
package.preload['parts.Defs']=function() return defs end
package.preload['urhox-libs/UI/Widgets/Panel']=function()
    return {Extend=function() return {} end}
end
TEXT_COMMANDS={}
package.preload['ui.SourceDraw']=function() return {
    Begin=function() end,Icon=function() end,Rect=function() end,
    Width=function(_,text,size) return utf8.len(tostring(text))*size end,
    Text=function(_,text,_,_,size,_,font) TEXT_COMMANDS[#TEXT_COMMANDS+1]={text=tostring(text),size=size,font=font} end,
} end
package.preload['ui.VoxTheme']=function() return {Thumbnail=function() return '' end} end
package.preload['ui.InventoryChrome']=function() return {icons={},Button=function(p) return {props=p,SetStyle=function() end} end} end
package.preload['ui.InventoryShadows']=function() return {Image=function() end} end
package.preload['ui.SourceButtonMotion']=function() return {Ease=function() return 1 end} end
package.preload['combat.WeaponDefs']=function() return {Stats=function(id) for _,c in ipairs(CATALOG) do if c.id==id then return c.ws end end end} end
for _,name in ipairs({'nvgSave','nvgGlobalAlpha','nvgTranslate','nvgRestore'}) do _G[name]=function() end end
NVG_ALIGN_RIGHT=2
local detail=require 'ui.InventoryDetail'
detail.props={viewportWidth=1920,viewportHeight=1080}
detail.inventory={hotbar={}}
detail.GetAbsoluteLayout=function() return {x=0,y=0,w=272,h=580} end
detail.RenderBackgroundImage=function() end;detail.AddChild=function() end;detail.SetStyle=function() end
detail:SetPart('laser1');detail:Render(0)
local count=0
for _,cmd in ipairs(TEXT_COMMANDS) do
    if cmd.size==24 then assert(cmd.font=='vox-tabular','core value must use tabular source digits');count=count+1 end
end
assert(count==3,'three primary numeric values')
RENDER_CHECKS=count+1
''')
checks += lua.globals().RENDER_CHECKS
paths = ['scripts/ui/InventoryDetail.lua', 'scripts/ui/InventoryDetailRows.lua']
report = {'result':'PASSED','assertions':checks,'parts':len(golden['cases']),
          'baseline':golden['baseline'],'lua':lua.eval('_VERSION'),
          'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
          'resourceDrift':golden['resourceDrift'],
          'scope':'Actual frozen inventory row statements versus Lua using current imported stats; actual Render font commands. Resource drift is separate and does not pass source balance parity. No raster, browser, native, or performance claim.'}
output = ROOT / 'docs/migration/evidence/inventory-detail-offline.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
