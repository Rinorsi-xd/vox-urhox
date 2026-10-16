"""Compare unchanged H5 encounter callbacks with actual Lua consumers, without GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
subprocess.run(['node', 'tools/migration/check-salvage-encounter-feedback-source.cjs'], check=True)
fixtures = json.loads((root / '.tmp/source-salvage-encounter-feedback.json').read_text(encoding='utf-8'))
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

files = ['scripts/salvage/Director.lua', 'scripts/salvage/Run.lua', 'scripts/salvage/Cinematics.lua', 'scripts/audio/SalvageAudio.lua', 'scripts/audio/AudioLevels.lua']
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
lua.globals().resources = table({name: json.loads((root / 'assets' / name).read_text(encoding='utf-8'))
                               for name in ['UI/Outgame.json', 'Salvage/RunData.json', 'Salvage/RevealSounds.json', 'Endless/Sounds.json']})
sounds = json.loads((root / 'assets/Endless/Sounds.json').read_text(encoding='utf-8'))['cues']
for name, source in fixtures['sounds'].items():
    cue = sounds[name]
    assert abs(cue['gain'] - source['gain']) < 1e-10 and cue['gap'] == source['gap']
    assert hashlib.sha256((root / 'assets' / cue['path']).read_bytes()).hexdigest() == source['sha256']
lua.globals().fixtures = table(fixtures)
checks = lua.execute((root / 'tools/migration/check-salvage-encounter-feedback.lua').read_text(encoding='utf-8'))
negative_controls = []
mutants = [
    ('clear beam missing', 'scripts/salvage/Director.lua', "self.run.fx:Loot(ground,({0xc9c1b2,0x3ddc84,0x3ea8ff,0xc46bff})[tier+1],0)", ''),
    ('ordinary alert counts dead cars', 'scripts/salvage/Director.lua', "..alive..' 辆车冲过来了'", "..#enc.units..' 辆车冲过来了'"),
    ('airdrop notice missing', 'scripts/salvage/Run.lua', "self.cine:NameCard('空投补给已落地','前方 '..math.floor(r+.5)..' 米 · 冒青烟的地方 · 附近的帮派也看见了',3.2)", ''),
    ('elite wreck flag missing', 'scripts/salvage/Run.lua', 'name=u.name,elite=u.elite,tier=1', 'name=u.name,tier=1'),
    ('death warning swapped', 'scripts/salvage/Run.lua', "self:Feed('战车被击毁','信号丢失……','#ff3420')", "self:Feed('信号丢失','战车被击毁')"),
    ('vault warning wrong strength', 'scripts/audio/SalvageAudio.lua', "id='urgent_warning',strength=.7", "id='urgent_warning',strength=.6"),
]
for label, name, before, after in mutants:
    original = (root / name).read_text(encoding='utf-8')
    assert before in original, label
    lua.globals().negativeCode = original.replace(before, after, 1)
    module = name.removeprefix('scripts/').removesuffix('.lua').replace('/', '.')
    lua.execute("package.loaded['salvage.Director']=nil; package.loaded['salvage.Run']=nil; package.loaded['salvage.Cinematics']=nil; package.loaded['audio.SalvageAudio']=nil; package.loaded['audio.AudioLevels']=nil; package.preload['" + module + "']=assert(load(negativeCode))")
    try:
        lua.execute((root / 'tools/migration/check-salvage-encounter-feedback.lua').read_text(encoding='utf-8'))
    except Exception as error:
        assert 'source' in str(error) or 'original elite wreck' in str(error), str(error)
        negative_controls.append({'name': label, 'result': 'REJECTED', 'failure': str(error).splitlines()[0]})
    else:
        raise AssertionError('Negative control not detected: ' + label)
    finally:
        lua.execute("package.preload['" + module + "']=nil")
assert hashes == {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
report = {'result': 'PASS', 'sourceCommit': fixtures['commit'], 'sourceHashes': fixtures['sourceHashes'],
          'productionHashes': hashes, 'runtime': lua.lua_implementation,
          'checks': [checks[i] for i in range(1, len(checks)+1)],
          'negativeControls': negative_controls,
          'audioAssets': fixtures['sounds'],
          'boundary': 'Actual frozen JS _alert/_cleared/_airdrop/afterStep versus actual Lua Director/Run/Cinematics, actual Lua SalvageAudio + AudioLevels with real asset SHA/gain/gap compared to frozen source. Units, physics, FX, UI, vectors, sound nodes/playback are adapters. No GPU, natural combat, extraction, visual, listening or performance acceptance.'}
out = root / 'docs/migration/evidence/salvage-encounter-feedback-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'evidence': str(out)}))
