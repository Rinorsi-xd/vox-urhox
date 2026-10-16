"""Execute the actual isolated Lua entry and frozen ResourceGate on CPU only."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def run(mode):
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute("""
now=0;step=0;result=nil;finished=false;events={};localFiles={};resident={};pending={}
Time={GetSystemTime=function() return now end}
graphics={apiName='CPU-fake'}
cjson={encode=function(value) result=value;return 'captured' end}
function print(...) end
function SubscribeToEvent(event,fn) events[event]=fn end
function UnsubscribeFromEvent(event) events[event]=nil end
cache={Exists=function(_,name) return localFiles[name]==true end,
 CancelDownloadGroup=function() end,
 DownloadResources=function(_,names,done) download={names=names,done=done};return 17 end,
 GetExistingResource=function(_,kind,name) assert(not inCallback,'Cache reentry from callback');return resident[name] end,
 BackgroundLoadResource=function(_,kind,name,fail) assert(not inCallback,'Background queue from callback');pending[name]=step+2;return true end}
""")
 gate=(root/'.tmp/outgame-cached-1792120761228/scripts/app/ResourceGate.lua').read_text(encoding='utf-8')
 lua.execute("package.preload['app.ResourceGate']=function()\n"+gate+'\nend')
 lua.globals().SOUND_CALLBACK_PROBE_CONFIG=lua.table_from({'mode':mode,'paths':lua.table_from(['sound-a.mp3','sound-b.wav'])})
 lua.execute((root/'tools/migration/probe-sound-callback.lua').read_text(encoding='utf-8'))
 lua.execute('Start()')
 for i in range(200):
  lua.execute("""
step=step+1;now=now+16
if download and step==30 then
 for _,name in ipairs(download.names) do localFiles[name]=true end
 inCallback=true;download.done(true,0);inCallback=false;download=nil
end
for name,readyStep in pairs(pending) do if readyStep<=step then resident[name]={compressed=true,dataSize=100};pending[name]=nil end end
SoundCallbackUpdate(nil,{GetFloat=function() return .016 end});SoundCallbackFrame()
""")
  if lua.globals().result is not None: break
 result=lua.globals().result
 assert result and result['result']=='PASS',(mode,result and result['message'])
 rows=result['rows'];assert len(rows)==2
 assert rows[1]['synchronous'] is False and rows[2]['synchronous'] is True
 for row in rows.values():
  assert row['nextUpdateFrame']>row['callbackFrame']
  if mode=='prepare':
   for resource in row['resources'].values():assert resource['readyWall']>=row['nextUpdateWall']
 assert len(result['frames'])>30
 lua.execute('Stop()')
 return len(result['frames'])

print({'result':'PASS','actualLuaFrames':{mode:run(mode) for mode in ['download','prepare']},'boundary':'CPU fake engine methods; actual Lua entry and frozen ResourceGate lifecycle, not native/Web evidence'})
