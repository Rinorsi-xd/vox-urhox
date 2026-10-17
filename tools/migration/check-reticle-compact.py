"""Exercise source startup policy and actual retained Lua HUD across resize."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source=json.loads(subprocess.check_output(['node',str(ROOT/'tools/migration/reticle-compact-source.mjs')],cwd=ROOT,text=True,encoding='utf-8'))
original=(ROOT/'scripts/ui/ReticleState.lua').read_text(encoding='utf-8')

def check(code):
    checks=0
    for case in source['cases']:
        for dpr in [1,2,3]:
            lua=LuaRuntime(unpack_returned_tuples=True)
            lua.execute("""
package.path='scripts/?.lua;'..package.path
package.preload['urhox-libs/UI']=function()return{}end
package.preload['urhox-libs.Platform.PlatformUtils']=function()return{IsMobilePlatform=function()return cfg.platform=='Android' or cfg.platform=='iOS'end}end
package.preload['ui.ReticleNavigation']=function()return{}end
graphics={GetDPR=function()return cfg.dpr end,GetWidth=function()return cfg.w*cfg.dpr end,GetHeight=function()return cfg.h*cfg.dpr end}
input={touchEmulation=false,GetNumTouches=function()return cfg.touches end}
function GetNativePlatform()return cfg.platform end
function GetPlatform()return cfg.platform end
function GetArguments()return cfg.args end
""")
            args=[]
            if case['forced'] is not None:args.append('-compact='+('1'if case['forced']else'0'))
            if case['name']=='touch-emulation':args.append('-touch')
            cfg=lua.table_from({'platform':case['platform'],'w':case['width'],'h':case['height'],
                                'dpr':dpr,'touches':0,'args':lua.table_from(args)})
            lua.globals().cfg=cfg
            module=lua.execute(code)
            touch=lua.eval("package.loaded['controls.TouchMode']")
            # The existing app fixes its home/build policy before creating a HUD.
            assert touch.Compact()==case['frames'][0]['compact']
            for frame in case['frames']:
                cfg.w=frame['width'];cfg.h=frame['height']
                cfg.touches=1 if case['touch'] else 0
                assert module.Compact()==frame['compact'],f"{case['name']} force={case['forced']} resize={cfg.w}x{cfg.h}"
                for scale in [1,.75,1.5]:
                    layout=module.Layout(cfg.w/scale,cfg.h/scale)
                    assert abs(layout.k*scale-frame['k'])<1e-12,'Actual source reticleScale vs retained Lua layout'
                    checks+=1
    return checks

checks=check(original)
old="""function M.Compact()
    local dpr=math.max(1,graphics:GetDPR())
    return TouchMode.Enabled() and math.min(graphics:GetWidth()/dpr,graphics:GetHeight()/dpr)<=600
end"""
negatives=[]
for name,replacement in [('old-dynamic-policy',old),('always-compact','function M.Compact() return true end'),
                         ('never-compact','function M.Compact() return false end')]:
    assert 'function M.Compact()\n    return TouchMode.Compact()\nend' in original
    mutated=original.replace('function M.Compact()\n    return TouchMode.Compact()\nend',replacement)
    try:check(mutated)
    except AssertionError as err:negatives.append({'name':name,'rejected':True,'reason':str(err)})
    else:raise AssertionError('Negative accepted '+name)
files=['scripts/ui/ReticleState.lua','scripts/controls/TouchMode.lua','tools/migration/reticle-compact-source.mjs','tools/migration/check-reticle-compact.py']
report={'status':'PASS','baseline':source['baseline'],'checks':checks,'negatives':negatives,
        'sourceHashes':source['sourceHashes'],'hashes':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest()for f in files},
        'boundary':'Actual frozen detectCompactUi/reticleScale versus actual Lua TouchMode/ReticleState. Matched available device inputs; source screen and native initial CSS viewport set equal. Does not solve unavailable browser pointer/screen metadata or certify target-device classification, rendering or FPS.'}
out=ROOT/'docs/migration/evidence/reticle-compact-2026-10-17.json'
if out.exists():raise FileExistsError('Preserve previous evidence')
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
