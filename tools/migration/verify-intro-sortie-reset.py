"""Compare frozen keyboard ownership with an isolated opening R candidate."""
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

CANDIDATE = ROOT / '.tmp/intro-sortie-r-candidate/scripts'
source = json.loads(subprocess.check_output(['node', 'tools/migration/source-intro-sortie-reset.mjs'], encoding='utf8'))

route = r'''
local noop=function()end
local checks={}
local function check(ok,label)assert(ok,label);checks[#checks+1]=label end
package.loaded['app.SceneLoader']={New=function()return{Update=noop}end}
local Host=assert(load(HOST_CODE))()
local host=Host.New({})
local s={pointer={captured=false,Poll=noop}}
host.state.session=s
s.Pause=function(self)self.pauses=(self.pauses or 0)+1 end
s.Flips=0;s.Flip=function(self)self.Flips=self.Flips+1 end
KEY_ESCAPE='escape';KEY_R='r';input={GetKeyPress=function(_,key)return key=='r' end}
host.Update(1/60,{ready=true,playing=true,time=0})
check(s.Flips==1,'source R reaches reset while opening owns playing input')
host.Update(1/60,{ready=true,playing=false,time=0,shot='idle'})
check(s.Flips==1,'nonplaying montage never resets from held R')
input.GetKeyPress=function(_,key)return key=='escape' end
host.Update(1/60,{ready=true,playing=true,time=0})
check(s.pauses==1 and s.Flips==1,'Escape remains release-only without a reset')
input.GetKeyPress=function()return false end
host.Update(1/60,{ready=true,playing=true,time=0})
check(s.Flips==1,'no R edge never starts a reset')
return #checks
'''
results = {}
for name, path in [('current', ROOT / 'scripts/app/OpeningHost.lua'), ('candidate', CANDIDATE / 'app/OpeningHost.lua')]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    host_code = path.read_text(encoding='utf8')
    lua.globals().HOST_CODE = host_code
    for dependency in re.findall(r'''require\s*\(?\s*['"]([^'"]+)''', host_code):
        lua.globals().package.loaded[dependency] = lua.table()
    try:
        result = lua.execute(route)
    except Exception as error:
        if name != 'current' or 'source R reaches reset' not in str(error):
            raise
        results[name] = {'status': 'EXPECTED_FAIL', 'failure': str(error).split('\n')[0]}
    else:
        assert name == 'candidate', 'Current production unexpectedly contains R route'
        results[name] = {'status': 'PASS', 'checks': result}

# Execute the actual isolated IntroSortieUi lifecycle with adapter widgets.
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().UI_CODE = (CANDIDATE / 'ui/IntroSortieUi.lua').read_text(encoding='utf8')
ui = lua.execute(r'''
local noop=function()end;local counters={resetDraw=0,resetDispose=0,rootDestroy=0}
local function module(name,value)package.loaded[name]=value end
local root={AddChild=noop,Destroy=function()counters.rootDestroy=counters.rootDestroy+1 end}
module('urhox-libs/UI',{Panel=function()return root end})
module('ui.MechReticle',function()return{Render=noop,Destroy=noop}end)
module('ui.DriveOverlay',{New=function()return{layer={Render=noop}}end})
module('ui.ResetProgress',{Attach=function(session,parent)
 assert(parent==root and session.resetChan.t==.4)
 return{layer={Render=function()counters.resetDraw=counters.resetDraw+1 end},Dispose=function()counters.resetDispose=counters.resetDispose+1 end}
end})
for _,name in ipairs({'ui.ReticleState','ui.ReticleGauges','ui.ReticleWeapons','ui.IntroSortieKill','ui.IntroTypography','ui.SourceDraw','core.Coord','ui.IntroSortieFx'})do module(name,{})end
module('ui.IntroOpacity',{Set=noop})
local UI=assert(load(UI_CODE))()
local session={resetChan={t=.4,dur=1.2}}
local view=UI.New(session)
local box=view.resetProgress.layer:GetAbsoluteLayout()
assert(box.w==1920 and box.h==1080)
view:Draw({}, {sortie={step=0,controlling=true}},1920,1080,10.8)
assert(counters.resetDraw==1)
view:Dispose()
assert(counters.resetDispose==1 and counters.rootDestroy==1 and session.openingOverlay==nil)
return counters
''')
results['ui'] = dict(ui.items())
results['candidateHashes'] = {str(p.relative_to(CANDIDATE)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [CANDIDATE / 'app/OpeningHost.lua', CANDIDATE / 'ui/IntroSortieUi.lua']}
print(json.dumps({'status': 'CANDIDATE_OFFLINE_PASS', 'source': source, 'results': results, 'boundary': 'Isolated candidate only; production unchanged. CPU adapters exercise real source keys, actual candidate host and UI lifecycle; real driving and rendered reset bar pending.'}, indent=2))
