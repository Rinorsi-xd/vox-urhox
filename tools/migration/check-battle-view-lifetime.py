"""Repeat actual visual lifetimes and summarize the immutable old Web OOM run."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('spawn_view_fixture', ROOT / 'tools/migration/check-spawn-view-cache.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)

CASE = r'''
local scene=Node();local source=Source();local combat=Combat.New(scene)
local rounds={}
local function Active()
 local n,m=0,0
 for _,value in ipairs(nodes)do if not value.disposed then n=n+1 end end
 for _,value in ipairs(materials)do if not value.disposed then m=m+1 end end
 return n,m
end
local baselineNodes,baselineMaterials=Active()
for round=1,30 do
 local world={viewEvents={},debris={events={}}};local units={}
 for i=1,3 do
  local bp=BP.New():Load(source);local unit={alive=true,bp=bp,vehicle=Vehicle(bp,round%2==0)}
  units[i]=unit;world.viewEvents[i]={type='unitSpawn',unit=unit}
 end
 combat:Consume(world)
 for _,unit in ipairs(units)do
  local drive=combat.units[unit];local id=6
  unit.bp:Remove(id);world.viewEvents={{type='partRemoved',unit=unit,id=id}};combat:Consume(world)
  drive:Bind(unit.bp,unit.vehicle)
  local part=BP.New():Load(source).parts[id];unit.bp.parts[id]=part
  world.viewEvents={{type='partRestored',unit=unit,id=id}};combat:Consume(world)
  drive:Bind(unit.bp,unit.vehicle)
  unit.alive=false;world.viewEvents={{type='unitKilled',unit=unit}};combat:Consume(world)
 end
 local n,m=Active()
 Check(n==baselineNodes,'Every completed spawn/damage/restore/rebind/kill round releases nodes')
 Check(m==baselineMaterials,'Every completed round releases private weapon/shell/livery materials')
 Check(next(combat.units)==nil and next(combat.pieces)==nil,'No retired combat units or pieces retained')
 rounds[round]={round=round,activeNodes=n,privateMaterials=m,createdNodes=#nodes,createdMaterials=#materials}
end
combat:Dispose();AssertFreed(scene)
return {rounds=rounds,checks=#checks}
'''


def plain(value):
    if hasattr(value, 'items'):
        keys = list(value.keys())
        if keys and all(isinstance(key, int) for key in keys):
            return [plain(value[i]) for i in range(1, len(keys) + 1)]
        return {key: plain(child) for key, child in value.items()}
    return value


def main():
    old = ROOT / '.tmp/outgame-cached-1792139145715'
    names = ['render.CombatView', 'render.DriveView', 'render.VehicleView', 'render.PartRig']
    identity = json.loads((old / 'identity.json').read_text(encoding='utf-8'))['identity']
    overrides = {name: (old / 'scripts' / (name.replace('.', '/') + '.lua')).read_text(encoding='utf-8') for name in names}
    for name, source in overrides.items():
        assert hashlib.sha256(source.encode()).hexdigest() == identity['scripts'][name.replace('.', '/') + '.lua']
    current = plain(fixture.runtime().execute(CASE))
    previous = plain(fixture.runtime(overrides=overrides).execute(CASE))
    rejected = []
    for label, name, before, after in [
        ('missing-unit-release', 'render.CombatView', 'if v then v:Dispose();self.units[e.unit]=nil end', 'if v then self.units[e.unit]=nil end'),
        ('missing-private-material-release', 'render.WeaponPresentation', 'for _,material in pairs(vis.weaponMaterials or {}) do material:Dispose() end', ''),
    ]:
        source = (ROOT / 'scripts' / (name.replace('.', '/') + '.lua')).read_text(encoding='utf-8')
        assert before in source
        try:
            fixture.runtime(overrides={name: source.replace(before, after)}).execute(CASE)
        except Exception as error:
            rejected.append({'name': label, 'failure': str(error).splitlines()[0]})
        else:
            raise AssertionError('Negative control passed: ' + label)
    run_dir = ROOT / 'docs/migration/evidence/story-natural-s4-manifest-279727d3-2026-10-16T08-35-25-117Z'
    run = json.loads((run_dir / 'result.json').read_text(encoding='utf-8'))
    assert run['errors'][0] == 'Aborted(OOM)'
    memory = [{'at': row['at'], 'heapCapacityBytes': row['heapBytes'], 'jsUsedBytes': row['jsHeap']['used'],
               'fsBytes': row['fileBytes'], 'logBytes': row['fsGroups']['/home/web_user/logs']}
              for row in run['memory']]
    object_counts = [{'stage': row['stage'], 'story': row['story'], 'world': row['objects']['world'],
                      'scene': row['objects']['scene'], 'views': row['objects']['combatViews'],
                      'weaponAudio': row['objects']['weaponAudio']} for row in run['objectSamples']]
    logs = {}
    resource_samples = []
    parse_failures = 0
    with (run_dir / 'runtime.log').open('rb') as source:
        for line in source:
            label = 'OUTGAME_STATE' if b'OUTGAME_STATE ' in line else 'OTHER'
            row = logs.setdefault(label, {'lines': 0, 'bytes': 0})
            row['lines'] += 1
            row['bytes'] += len(line)
            if label == 'OUTGAME_STATE':
                try:
                    state = json.loads(line.split(b'OUTGAME_STATE ', 1)[1])
                except (ValueError, UnicodeDecodeError):
                    parse_failures += 1
                    continue
                if state.get('mode') == 'trial' and 'performance' in state:
                    perf = state['performance']
                    resource_samples.append({'storyTime': state.get('story', {}).get('time'),
                        **{name: perf.get(name) for name in ['luaKiB', 'resourceBytes', 'modelBytes', 'soundBytes',
                                                            'materialBytes', 'imageBytes', 'retiredTargets']}})
    ranges = {name: {'min': min(row[name] for row in resource_samples), 'max': max(row[name] for row in resource_samples)}
              for name in ['luaKiB', 'resourceBytes', 'modelBytes', 'soundBytes', 'materialBytes', 'imageBytes', 'retiredTargets']}
    report = {'result': 'PASS', 'current': current, 'old2797': previous, 'negativeControls': rejected, 'webEvidence': {
        'run': str(run_dir.relative_to(ROOT)), 'resultSha256': hashlib.sha256((run_dir / 'result.json').read_bytes()).hexdigest(),
        'errors': run['errors'], 'lastStoryTime': run['lastState']['story']['time'],
        'lastStats': run['lastState']['story']['stats'], 'memory': memory, 'objects': object_counts, 'runtimeLog': logs,
        'resourceSamples': {'count': len(resource_samples), 'parseFailures': parse_failures, 'ranges': ranges,
                            'first': resource_samples[0], 'last': resource_samples[-1], 'periodic': resource_samples[::200]}},
        'inputs': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [
            'scripts/render/CombatView.lua', 'scripts/render/DriveView.lua', 'scripts/render/VehicleView.lua',
            'scripts/render/PartRig.lua', 'tools/migration/check-battle-view-lifetime.py',
            'tools/migration/check-spawn-view-cache.py']},
        'boundary': 'Actual Lua view/rig/material and joined/livery lifetime paths under node/material adapters, 30 rounds x three cars for both old actual frozen sources and current. Equipment effects and native backend are adapted. This cannot prove native heap/GPU/audio/physics release or identify the OOM allocator. Existing Web counts and FS bytes are read-only historical evidence; heap capacity is not live native occupancy.'}
    output = ROOT / 'docs/migration/evidence/battle-view-lifetime-offline.json'
    output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'result': 'PASS', 'currentRounds': len(current['rounds']), 'oldRounds': len(previous['rounds']),
                      'currentLast': current['rounds'][-1], 'oldLast': previous['rounds'][-1], 'negativeControls': len(rejected), 'logs': logs}))


if __name__ == '__main__':
    main()
