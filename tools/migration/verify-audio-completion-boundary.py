"""Catch actual frozen audio callback re-entry with both ResourceGate backends."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

UI=ROOT/'scripts/audio/UiSound.lua'
PAGE=ROOT/'scripts/audio/StoryPageVoice.lua'
FIXTURE=ROOT/'tools/migration/check-audio-completion-boundary.lua'
FROZEN=ROOT/'.tmp/outgame-cached-1792128891583/scripts/audio'
data=json.loads((ROOT/'assets/UI/Sounds.json').read_text(encoding='utf-8'))
page_host=(ROOT/'scripts/ui/StoryPage.lua').read_text(encoding='utf-8')
page_update=re.search(r'function M.Update\(s,dt\).*?(?=\nfunction M.Key)',page_host,re.S).group()
page_leave=re.search(r'function M.Leave\(s\).*?(?=\nfunction M.Start)',page_host,re.S).group()
app=(ROOT/'scripts/app/HangarApp.lua').read_text(encoding='utf-8')
assert "require('app.ResourceGate').UpdatePending(dt)\n    require('audio.UiSound').Update()"in app,'Live app still drives the deferred sound queue'

def run(ui,page):
    lua=LuaRuntime(unpack_returned_tuples=True)
    def table(value):
        if isinstance(value,dict):return lua.table_from({k:table(v)for k,v in value.items()})
        if isinstance(value,list):return lua.table_from([table(v)for v in value])
        return value
    lua.globals().SOUND_DATA=table(data)
    lua.globals().UI_SOURCE=ui
    lua.globals().PAGE_SOURCE=page
    lua.globals().PAGE_HOST_SOURCE=page_update+'\n'+page_leave
    lua.globals().print=lambda *args:None
    return dict(lua.execute(FIXTURE.read_text(encoding='utf-8')).items())

ui,page=UI.read_text(encoding='utf-8'),PAGE.read_text(encoding='utf-8')
result=run(ui,page)
negative=[]
for name in ['UiSound.lua','StoryPageVoice.lua']:
    old=(FROZEN/name).read_text(encoding='utf-8')
    try:run(old if name=='UiSound.lua'else ui,old if name=='StoryPageVoice.lua'else page)
    except Exception as error:
        assert 'cache operation inside download completion'in str(error),str(error)
        negative.append({'case':'actual frozen bb6e '+name,'sha256':hashlib.sha256((FROZEN/name).read_bytes()).hexdigest(),'failure':str(error).split('\n')[0]})
    else:raise AssertionError('Frozen callback regression unexpectedly passed '+name)

paths=['scripts/audio/UiSound.lua','scripts/audio/StoryPageVoice.lua','scripts/app/ResourceGate.lua','scripts/audio/AudioLevels.lua','scripts/ui/StoryPage.lua','scripts/app/HangarApp.lua']
tools=['tools/migration/check-audio-completion-boundary.lua','tools/migration/verify-audio-completion-boundary.py']
assert UI.read_text(encoding='utf-8')==ui and PAGE.read_text(encoding='utf-8')==page,'Production changed during verification'
report={**result,'negativeControls':negative,
        'productionHashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        'testInputs':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in tools}}
(ROOT/'docs/migration/evidence/audio-completion-boundary-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
