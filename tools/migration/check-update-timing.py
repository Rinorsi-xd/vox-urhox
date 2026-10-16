"""Execute the actual QA timing helpers and HandleUpdate without browser/GPU."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

probe = ROOT / 'tools/migration/probe-outgame-web.lua'
source = probe.read_text(encoding='utf-8')
header = source[:source.index('VOX_SKIP_TUTORIAL=true')]
update = source[source.index('function HandleUpdate(et,ed)'):source.index('\nlocal originalPostUpdate=HandlePostUpdate')]


def run(candidate):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        wall=0;checks=0;messages={};KEY_F8='F8'
        Time={GetSystemTime=function()return wall end}
        print=function(text)messages[#messages+1]=text end
        input={GetKeyPress=function()return false end}
        -- Simulate the engine's separate require cache: package.loaded is empty.
        package={loaded={}}
        local gate={UpdatePending=function(dt)wall=wall+3;return dt end}
        gate.__index=gate
        function MakeApp()
            local music={}
            function music:PreparePending(dt)wall=wall+5;return dt end
            function music:Next(token)wall=wall+7;return token,nil,'third',false end
            function music:Update(dt)self:PreparePending(dt);self:Next(dt)end
            local app={music=music,vehicleGate=setmetatable({},gate)}
            function app:AdvanceOpeningRetirements()wall=wall+2 end
            function app:Update(dt)
                self:AdvanceOpeningRetirements();gate.UpdatePending(dt)
                self.music:Update(dt);wall=wall+11
            end
            return app
        end
        actual=MakeApp();VOX_HANGAR={app=actual}
        function HandleUpdate(_,dt)actual:Update(dt)end
    ''')
    lua.execute(candidate + '''
        local frames=0;local samples={};local sampleMode=''
        local Dump=function()end
    ''' + update + '\nTIMING=updateTiming')
    return lua.execute('''
        local function Check(ok,label)checks=checks+1;assert(ok,label)end
        for i=1,8 do HandleUpdate('Update',.016)end
        for _,name in ipairs({'app.HangarApp.Update','app.HangarApp.AdvanceOpeningRetirements',
                'audio.MusicPlayer.Update','audio.MusicPlayer.Next','audio.MusicPlayer.PreparePending',
                'app.ResourceGate.UpdatePending'})do
            local t=TIMING[name]
            Check(t and t.calls==8,'actual nonzero count, no nested wrappers: '..name)
        end
        Check(TIMING['app.HangarApp.Update'].totalMs==224,'outer Update inclusive actual time')
        Check(TIMING['audio.MusicPlayer.Update'].maxMs==12,'nested music time')
        Check(TIMING['app.ResourceGate.UpdatePending'].totalMs==24,'static gate dispatch captured')
        local a,b,c,d=actual.music:Next('token')
        Check(a=='token' and b==nil and c=='third' and d==false,'method self/arguments/returns retained')
        VOX_HANGAR=nil;VOX_TRIAL=nil;HandleUpdate('Update',.016)
        Check(TIMING['app.HangarApp.Update'].calls==9,'retained instance timed while globals absent')
        actual=MakeApp();VOX_HANGAR={app=actual};HandleUpdate('Update',.016)
        Check(TIMING['app.HangarApp.Update'].calls==10,'replacement app and music bound')
        Check(TIMING['audio.MusicPlayer.PreparePending'].calls==10,'replacement nested method bound')
        actual.Update=function()wall=wall+130;return 'replacement'end
        HandleUpdate('Update',.016)
        local t=TIMING['app.HangarApp.Update']
        Check(t.calls==11 and t.maxMs==130 and t.slowCalls==1,'replaced method and long-call capture')
        Check(t.maxEndWall-t.maxStartWall==130,'absolute long-call interval retained')
        Check(messages[1]:find('[QAUpdateTiming] app.HangarApp.Update ms=130',1,true)~=nil,'long-call log emitted')
        Check(next(package.loaded)==nil,'no module cache mutation or eager require')
        return {checks=checks,appCalls=t.calls,gateCalls=TIMING['app.ResourceGate.UpdatePending'].calls,
            musicCalls=TIMING['audio.MusicPlayer.Update'].calls,maxAppMs=t.maxMs}
    ''')


result = dict(run(header))
negative_controls = []
for name, candidate in [
    ('missing-instance-binding', header.replace("WrapUpdateTiming(app,'Update','app.HangarApp.Update')", '')),
    ('nested-wrapper', header.replace('if methods[method]==object[method] then return end', '')),
]:
    assert candidate != header
    try:
        run(candidate)
    except Exception as error:
        negative_controls.append({'name': name, 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control passed: ' + name)
report = {'result': 'PASS', **result, 'negativeControls': negative_controls,
          'probeSha256': hashlib.sha256(probe.read_bytes()).hexdigest(),
          'toolSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'boundary': 'Actual extracted QA helpers and full HandleUpdate with controlled dispatch/clock; engine-like require cache absent from package.loaded. Nonzero CPU fixture counters, not Web runtime timing or audible continuity.'}
out = ROOT / 'docs/migration/evidence/update-timing-offline.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
