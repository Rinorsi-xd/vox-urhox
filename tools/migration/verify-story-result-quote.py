"""Compare actual frozen result voice timing with actual Lua communications."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime


def main():
    os.chdir(ROOT)
    source = json.loads(subprocess.check_output(
        ['node', '--experimental-vm-modules', 'tools/migration/story-result-quote-source.mjs'], text=True, encoding='utf-8'))
    lua = LuaRuntime(unpack_returned_tuples=True)

    def convert(value):
        if isinstance(value, dict):
            return lua.table_from({key: convert(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([convert(item) for item in value])
        return value

    lua.globals().SOURCE = convert(source)
    result = dict(lua.execute((ROOT / 'tools/migration/check-story-result-quote.lua').read_text(encoding='utf-8')))
    registry_check = json.loads(subprocess.check_output(
        ['node', '--experimental-vm-modules', 'tools/migration/import-story-result-voices.mjs', '--check'], text=True, encoding='utf-8'))
    files = {f'Story/Mission/Level{i}.json': json.loads((ROOT / f'assets/Story/Mission/Level{i}.json').read_text(encoding='utf-8')) for i in range(1, 6)}
    registry = json.loads((ROOT / 'assets/Story/Mission/ResultVoices.json').read_text(encoding='utf-8'))
    files['Story/Mission/ResultVoices.json'] = registry
    lua.globals().FILES = convert(files)
    media_checks = lua.execute(r'''
package.preload['core.ResourceData']=function() return {Read=function(path) return FILES[path] end} end
package.loaded['story.MissionData']=nil
local data=require 'story.MissionData'
local C=require 'audio.StoryComms';local count=0
local dependencies={};for _,path in ipairs(C.Dependencies()) do dependencies[path]=true end
for _,quote in ipairs(FILES['Story/Mission/ResultVoices.json'].quotes) do
 C.Shutdown();local voice=C.New(nil,data);voice:PrepareResultQuote(quote.text)
 if quote.id then
  assert(voice.resultQuote and voice.resultQuote.id==quote.id,'actual merged voice index resolves authored grade quote')
  assert(dependencies[voice.resultQuote.path],'actual ResourceGate dependencies retain grade recording')
  count=count+2
 else assert(voice.resultQuote==nil,'unrecorded source Boss quote stays silent');count=count+1 end
end
C.Shutdown();return count
''')
    ffmpeg = os.environ.get('VOX_FFMPEG')
    if not ffmpeg:
        import imageio_ffmpeg
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    decoded = []
    for voice_id, voice in registry['voices'].items():
        output = subprocess.check_output([ffmpeg, '-v', 'error', '-i', str(ROOT / 'assets' / voice['path']), '-f', 's16le', '-acodec', 'pcm_s16le', '-'])
        if len(output) <= 48000 or not any(output):
            raise AssertionError(f'Empty or truncated grade recording: {voice_id}')
        decoded.append({'id': voice_id, 'seconds24kMono': len(output) / 48000, 'bytes': (ROOT / 'assets' / voice['path']).stat().st_size})
    result['checks'] += media_checks + len(decoded)
    result['resultVoiceRegistry'] = registry_check
    result['decodedOriginalRecordings'] = decoded
    result['recordingSource'] = registry['source']
    result['source'] = source['source']
    result['production'] = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in
                            ['scripts/story/Mission.lua', 'scripts/audio/StoryComms.lua', 'scripts/story/MissionData.lua', 'assets/Story/Mission/ResultVoices.json']}
    output = ROOT / 'docs/migration/evidence/story-result-quote-offline.json'
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
