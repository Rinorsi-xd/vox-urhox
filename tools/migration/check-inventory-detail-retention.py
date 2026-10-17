"""Exercise actual InventoryPanel/Detail and full ScrollView consumer methods."""
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
golden = json.loads(subprocess.check_output(['node', 'tools/migration/source-inventory-scroll-golden.cjs'], encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;?.lua;'..package.path")

def convert(value):
    if isinstance(value, dict):
        return lua.table_from({key: convert(item) for key, item in value.items() if item is not None})
    if isinstance(value, list):
        return lua.table_from([convert(item) for item in value])
    return value

lua.globals().ASSETS = convert({name: json.loads((ROOT/'assets'/name).read_text(encoding='utf-8'))
                               for name in ['Parts/Catalog.json','Combat/Weapons.json']})
lua.execute('''
package.preload['core.ResourceData']=function() return {Read=function(path) return assert(ASSETS[path],path) end} end
local Widget={}
function Widget:Extend()
    local cls={};cls.__index=cls
    return setmetatable(cls,{__index=self})
end
package.preload['urhox-libs/UI/Core/Widget']=function() return Widget end
package.preload['urhox-libs/UI/Widgets/Panel']=function() return Widget end
for _,name in ipairs({'urhox-libs/UI/Core/Theme','urhox-libs/UI/Core/Style','urhox-libs/UI/Core/UI',
 'urhox-libs/UI/Core/PointerEvent','urhox-libs/UI','urhox-libs/UI/Core/Input','audio.UiSound',
 'ui.InventorySearch','ui.InventoryList','ui.BuildHotbar','render.SceneBackdrop','controls.TouchMode',
 'ui.InventoryCardMotion','ui.InventoryKeys','ui.InventoryShadows','ui.VoxTheme','construction.Inventory',
 'ui.SourceButtonMotion','ui.SourceDraw','ui.InventoryDetailLayout'}) do
    package.preload[name]=function() return {} end
end
package.preload['ui.InventoryChrome']=function() return {icons={}} end
PANEL=require 'ui.InventoryPanel'
DETAIL=require 'ui.InventoryDetail'
SCROLL=require 'ui.InventoryDetailScroll'
BASE=require 'urhox-libs/UI/Widgets/ScrollView'
function Fixture(viewport,top,bottom,height,offset,expanded)
    local detail=setmetatable({props={height=height},children={},expanded=expanded},DETAIL)
    function detail:GetLayout() return {x=25,y=top,w=272,h=self.props.height} end
    local scroll=setmetatable({props={bounces=false,scrollY=true,paddingTop=top,paddingBottom=bottom},
        state={scrollX=0,scrollY=offset,velocityX=0,velocityY=0},children={detail}},SCROLL)
    function scroll:GetLayout() return {x=0,y=0,w=310,h=viewport} end
    scroll:UpdateContentSize()
    local owner=setmetatable({detail=detail,detailScroll=scroll,shown=false},PANEL)
    return owner,detail,scroll
end
''')

checks = 0
failures = []
cases = []
for case in golden['cases']:
    owner, detail, scroll = lua.globals().Fixture(392,8,12,1200,case['offset'],case['expanded'])
    owner.Detail(owner,case['id'])
    retained = scroll.state.scrollY == case['scrollTop']
    if not retained:
        failures.append({'case':case,'actual':scroll.state.scrollY,'reason':'switch reset retained offset'})
    assert owner.shown == case['shown'] and detail.partType == case['id']
    assert len(detail.rows) >= 5 and detail.expanded == case['expanded']
    checks += 4
    cases.append({'id':case['id'],'expanded':case['expanded'],'offset':case['offset'],'actual':scroll.state.scrollY})

# Layout rectangles are fixtures. Use the actual local subclass and inherited
# wheel/clamp methods after changing the same real detail child height.
clamp_cases=[]
for viewport,top,bottom in [(697,18,16),(392,8,12)]:
    for height,offset in [(1200,73),(1200,287),(500,287),(30,287),(0,73)]:
        owner,detail,scroll=lua.globals().Fixture(viewport,top,bottom,1200,offset,True)
        owner.Detail(owner,'tianyuanDrill')
        detail.props.height=height
        for _ in range(3):
            scroll.UpdateContentSize(scroll)
            expected=min(offset,max(0,top+height+bottom-viewport))
            if scroll.state.scrollY != expected:
                failures.append({'height':height,'offset':offset,'viewport':viewport,'actual':scroll.state.scrollY,'expected':expected,'reason':'out of range after content shrink'})
            checks += 1
        scroll.ScrollBy(scroll,0,-17)
        if scroll.state.scrollY != max(0,expected-17):
            failures.append({'actual':scroll.state.scrollY,'expected':max(0,expected-17),'reason':'wheel continuation changed retained offset'})
        checks += 1
        clamp_cases.append({'height':height,'offset':offset,'viewport':viewport,'expected':expected})

lua.execute('''
local owner,detail,scroll=Fixture(392,8,12,1200,73,true)
local events=0
scroll.props.onScroll=function() events=events+1 end
owner:Detail('laser1')
for i=1,4 do scroll:UpdateContentSize() end
assert(events==0 and scroll.state.scrollY==73,'Stable content must not emit scroll callbacks')
detail.props.height=30
scroll:UpdateContentSize()
assert(events==1 and scroll.state.scrollY==0,'One actual clamp notification')
for i=1,4 do scroll:UpdateContentSize() end
assert(events==1,'No repeat notifications after clamp')
scroll.state.scrollY=73
scroll.GetLayout=function() return {x=0,y=0,w=310,h=0/0} end
scroll:UpdateContentSize()
assert(scroll.state.scrollY==73 and events==1,'Transient NaN layout must retain offset')
scroll.GetLayout=function() return {x=0,y=0,w=310,h=0} end
scroll:UpdateContentSize()
assert(scroll.state.scrollY==73 and events==1,'Transient zero layout must retain offset')
EDGE_CHECKS=5

local controls={}
local original=PANEL.Detail
PANEL.Detail=function(self,id) original(self,id);self.detailScroll:ScrollToTop() end
owner,detail,scroll=Fixture(392,8,12,1200,73,true)
owner:Detail('laser1')
assert(scroll.state.scrollY~=73,'Reset-offset negative control must fail retention')
controls[#controls+1]='force-reset-rejected'
PANEL.Detail=original

local update=SCROLL.UpdateContentSize
SCROLL.UpdateContentSize=function(self)
    BASE.UpdateContentSize(self)
    self.contentHeight_=self.contentHeight_+(self.props.paddingBottom or 0)
end
owner,detail,scroll=Fixture(392,8,12,1200,287,true)
detail.props.height=30;scroll:UpdateContentSize()
assert(scroll.state.scrollY~=0,'Missing-clamp negative control must fail short content')
controls[#controls+1]='missing-clamp-rejected'
SCROLL.UpdateContentSize=update

local setPart=DETAIL.SetPart
DETAIL.SetPart=function() end
owner,detail,scroll=Fixture(392,8,12,1200,73,true)
owner:Detail('laser1')
assert(detail.partType~='laser1' and detail.rows==nil,'No-op actual detail consumer must fail')
controls[#controls+1]='missing-detail-consumer-rejected'
DETAIL.SetPart=setPart
NEGATIVE_CONTROLS=controls
''')
checks += lua.globals().EDGE_CHECKS + len(lua.globals().NEGATIVE_CONTROLS)
paths=['scripts/ui/InventoryPanel.lua','scripts/ui/InventoryDetail.lua','scripts/ui/InventoryDetailScroll.lua']
report={'result':'FAIL' if failures else 'PASS','checks':checks,'baseline':golden['baseline'],
 'sourceSha256':golden['sourceSha256'],'cases':cases,'clampCases':clamp_cases,'failures':failures,
 'negativeControls':list(lua.globals().NEGATIVE_CONTROLS.values()),
 'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
 'boundary':'Complete frozen H5 _detail method and real Lua InventoryPanel:Detail, InventoryDetail:SetPart/rows/WeaponDefs plus actual full ScrollView module. DOM sinks and layout rectangles are adapters; no browser/Yoga/NanoVG/performance acceptance.'}
output=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'docs/migration/evidence/inventory-detail-retention-offline.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'checks':checks,'failures':len(failures),'output':str(output)}))
if failures:
    sys.exit(1)
