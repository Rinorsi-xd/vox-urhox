"""Exercise the actual isolated Web probe state machine without starting an engine."""
from pathlib import Path
import json
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
source=(ROOT/'tools/migration/probe-array-preparation.lua').read_text(encoding='utf-8')


def run(mode='background',bad_layers=False,never_ready=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().MODE=mode
    lua.globals().BAD_LAYERS=bad_layers
    lua.globals().NEVER_READY=never_ready
    lua.execute('''
        wall=0;frame=0;messages={};existing={};pending={};queueCalls=0;syncCalls=0;releaseCalls=0
        ARRAY_PROBE_CONFIG={mode=MODE,arrays={{name='a.xml',binding='tAlb'},{name='n.xml',binding='tNra'}},
            downloads={'a.xml','n.xml'},material='material.xml',width=1024,height=1024,levels=11,memoryBytes=33554792}
        cjson={encode=function(v)RESULT=v;return 'result'end}
        Time={GetSystemTime=function()return wall end};graphics={apiName='fixture'}
        function SubscribeToEvent()end;function UnsubscribeFromEvent()end
        print=function(s)messages[#messages+1]=s end
        local function resource()
            return {width=1024,height=1024,layers=BAD_LAYERS and 5 or 6,levels=11,memoryUse=33554792,format=4}
        end
        cache={Exists=function()return true end,
            GetExistingResource=function(_,_,name)return existing[name]end,
            GetNumBackgroundLoadResources=function()local n=0;for _ in pairs(pending)do n=n+1 end;return n end,
            BackgroundLoadResource=function(_,typ,name)
                assert(typ=='Texture2DArray');queueCalls=queueCalls+1;pending[name]=frame+2;wall=wall+2;return false
            end,
            GetResource=function(_,typ,name)
                if typ=='Material' then return {GetSurfaceTexture=function(_,binding)return existing[binding=='tAlb' and 'a.xml' or 'n.xml']end}end
                syncCalls=syncCalls+1;wall=wall+700;existing[name]=resource();return existing[name]
            end,
            ReleaseResource=function(_,_,name)existing[name]=nil;releaseCalls=releaseCalls+1 end}
        package.loaded['app.ResourceGate']={New=function()return {Cancel=function()end,Start=function(_,_,done)done(true)end}end,
            UpdatePending=function()end}
        function Pump()
            frame=frame+1;wall=wall+16
            for name,due in pairs(pending)do
                if frame>=due and not NEVER_READY then existing[name]=resource();pending[name]=nil end
            end
            ArrayProbeUpdate(nil,{GetFloat=function()return .016 end});ArrayProbeFrame()
        end
    ''')
    lua.execute(source)
    lua.execute('Start();for i=1,4000 do if RESULT then break end;Pump()end')
    result=lua.globals().RESULT
    assert result is not None,'Probe must end with an explicit outcome'
    if bad_layers or never_ready:
        assert result['result']=='FAIL'
        assert ('six layers' if bad_layers else 'timeout') in result['message']
        return
    assert result['result']=='PASS',result['message']
    assert len(result['rows'])==2
    assert all(row['referenceMatched'] for row in result['rows'].values())
    assert result['cleanup']['pendingBackground']==0
    assert not any(result['cleanup']['residual'].values())
    assert lua.globals().releaseCalls==3
    if mode=='background':
        assert lua.globals().syncCalls==0,'Background candidate must never synchronously decode arrays'
        assert lua.globals().queueCalls==2
        assert all(row['queueMs']==2 for row in result['rows'].values())
        assert max(row['ms'] for row in result['frames'].values())<250
    else:
        assert lua.globals().syncCalls==2
        assert max(row['ms'] for row in result['frames'].values())>=700,'Whole-frame recording catches blocking calls'


run();run('synchronous');run(bad_layers=True);run(never_ready=True)
print(json.dumps({'result':'PASS','scenarios':4,'scope':'Actual Lua probe with controlled engine/cache: async false queue return, sync stall recording, wrong layer failure and timeout cleanup. Not target API or performance acceptance.'}))
