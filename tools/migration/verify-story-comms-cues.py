"""Compare actual retained communications transitions with frozen NonoComms."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

LUA = r'''
package.path='scripts/?.lua;'..package.path
local checks,missing,requested=0,0,{}
local function Check(value,message) checks=checks+1;assert(value,message) end
Scene=function() return {CreateChild=function() return {CreateComponent=function() return {
 SetSoundType=function() end,StopImmediate=function() end,
} end} end,Dispose=function() end} end
cache={GetResourceAsync=function() end}
audio={PauseSoundType=function() end,ResumeSoundType=function() end}
package.preload['audio.AudioLevels']=function() return {RawGain=function() return .4 end,SetSpeaking=function() end} end
package.preload['ui.CommsCard']=function() return {Tick=function() end,Dispose=function() end} end
package.preload['audio.StoryCommsCues']=function() return {New=function() return {
 Play=function(_,name) requested[#requested+1]=name end,Update=function() end,Dispose=function() end,
} end} end
local Comms=require 'audio.StoryComms'
for _,sample in ipairs(SOURCE.cases) do
 Comms.Shutdown();requested={}
 local card=Comms.New(nil,{voices={}},sample.keepOpen)
 for i,op in ipairs(sample.ops) do
  if op.action=='say' then card:Say(op.lines,op.urgent,op.append)
  elseif op.action=='update' then card:Update(op.dt,true)
  elseif op.action=='hide' then card:Hide()
  elseif op.action=='present' then card:Present(op.who,'test',nil,0,0,1,0,1) end
  local expected=sample.trace[i]
  local match=#requested==#expected.cues
  for j,cue in ipairs(expected.cues) do match=match and requested[j]==cue end
  if not match then missing=missing+1 end
  if not EXPECT_MISSING then Check(match,sample.name..' step '..i..' original communications cue sequence') end
  -- Present borrows visuals only; its externally owned card is not an ordinary line.
  if sample.name~='external-cinematic-is-silent' then
   Check(card:Talking()==expected.talking and #card.queue==expected.queue,sample.name..' step '..i..' existing line lifecycle')
  end
 end
 card:Dispose()
end
Comms.Shutdown()
if EXPECT_MISSING then Check(missing>0,'old production must reproduce missing original cue events') end
return {result=EXPECT_MISSING and 'REPRODUCED_MISSING_CUES' or 'PASS',checks=checks,
 scenarios=#SOURCE.cases,mismatchedSampledSteps=missing,
 boundary='Actual complete frozen NonoComms and actual Lua StoryComms retained-card transitions with native-free DOM/audio adapters. Cue dispatcher is an observer double; separate asynchronous/audio-pool checks required. No audible, Web, or native acceptance.'}
'''


def main():
    os.chdir(ROOT)
    source = json.loads(subprocess.check_output(
        ['node', '--experimental-vm-modules', 'tools/migration/story-comms-cues-source.mjs'],
        text=True, encoding='utf-8'))
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().SOURCE = convert(source)
    lua.globals().EXPECT_MISSING = '--expect-missing' in sys.argv
    result = dict(lua.execute(LUA))
    if not lua.globals().EXPECT_MISSING:
        baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
        radio_data = json.loads((ROOT / 'assets/Story/Radio/Radio.json').read_text(encoding='utf-8'))
        verified_assets = []
        for name, cue in radio_data['cues'].items():
            assert source['cuesByName'][name] == [cue['id'], cue['strength']], f'Original cue mapping: {name}'
            authored = (Path(baseline['snapshot']) / cue['source']).read_bytes()
            packaged = (ROOT / 'assets' / cue['path']).read_bytes()
            assert authored == packaged, f'Original approved recording: {name}'
            assert hashlib.sha256(packaged).hexdigest() == cue['sha256']
            verified_assets.append(cue['path'])
        result['approvedSourceAssets'] = verified_assets
        result['checks'] += len(verified_assets) * 3
        fixture = (ROOT / 'tools/migration/check-story-comms-cue-loading.lua').read_text(encoding='utf-8')

        def execute_loading(code=None):
            loader = LuaRuntime(unpack_returned_tuples=True)

            def loader_value(value):
                if isinstance(value, dict):
                    return loader.table_from({key: loader_value(item) for key, item in value.items()})
                if isinstance(value, list):
                    return loader.table_from([loader_value(item) for item in value])
                return value

            loader.globals().RADIO_DATA = loader_value(radio_data)
            if code is not None:
                loader.globals().TEST_CODE = code
            return dict(loader.execute(fixture))

        loading = execute_loading()
        result['loading'] = loading
        result['checks'] += loading['checks']
        production = (ROOT / 'scripts/audio/StoryCommsCues.lua').read_text(encoding='utf-8')
        historical_path = 'docs/migration/evidence/history/StoryCommsCues-before-callback-deferral-20261016.lua'
        historical = (ROOT / historical_path).read_text(encoding='utf-8')
        assert hashlib.sha256(historical.encode()).hexdigest() == 'b138bb0f4c224bffa048fee80a0a71a56808ac3721b3dbd296b660ef624a8a41'
        controls = [
            ('actual old frozen production', historical, 'download callback lock'),
            ('cache query inside callback', production.replace('self.downloadReady=ok==true', "cache:GetExistingResource('Sound','forbidden');self.downloadReady=ok==true"), 'download callback lock'),
            ('audio allocation inside callback', production.replace('self.downloadReady=ok==true', 'Radio.New();self.downloadReady=ok==true'), 'download callback lock'),
            ('error logging inside callback', production.replace('self.downloadError=not ok and tostring(message) or nil', "if not ok then print(message) end;self.downloadError=not ok and tostring(message) or nil"), 'download callback lock'),
            ('readiness consumed more than once', production.replace('self.downloadReady=false;self.preparing=true', 'self.downloadReady=true;self.preparing=true'), 'resubmit background jobs'),
            ('error consumed more than once', production.replace('self.downloadError=nil', 'self.downloadError=self.downloadError'), 'failed download never'),
            ('disposed Update resumes ready marker', production.replace('function M:Update(dt,focus)\n    if self.disposed then return end', 'function M:Update(dt,focus)'), 'first Update discards ready marker'),
        ]
        rejected = []
        for name, code, expected in controls:
            assert code != production, f'{name}: mutation not applied'
            try:
                execute_loading(code)
            except Exception as error:
                assert expected in str(error), f'{name}: unexpected rejection {error}'
                rejected.append({'name': name, 'reason': str(error), 'sha256': hashlib.sha256(code.encode()).hexdigest()})
            else:
                raise AssertionError('Negative control not rejected: ' + name)
        result['negativeControls'] = rejected
        result['checks'] += len(rejected) + 1
        result['testInputs'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                              ['tools/migration/verify-story-comms-cues.py', 'tools/migration/check-story-comms-cue-loading.lua', historical_path]}
    result['source'] = source['source']
    result['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                            ['scripts/audio/StoryComms.lua', 'scripts/audio/StoryCommsCues.lua',
                             'scripts/audio/StoryRadio.lua', 'scripts/app/ResourceGate.lua',
                             'assets/Story/Radio/Radio.json', 'scripts/story/Tutorial.lua']}
    suffix = '-before' if lua.globals().EXPECT_MISSING else ''
    output = ROOT / f'docs/migration/evidence/story-comms-cues{suffix}-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
