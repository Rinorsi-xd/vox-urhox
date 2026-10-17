"""Resolve measured Web compile identities through source metadata and scene XML."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/migration/evidence/performance-uninstrumented-match-1792164528056'
LOG = EVIDENCE / 'runtime.log'
lines = LOG.read_text('utf8').splitlines()
metadata = ['Scatter', 'Map-MAP_ROCK-MAP_VBAKE', 'Map-MAP_BAKE-MAP_PANEL-MAP_SOOT',
            'Map-MAP_NOSAND-MAP_PANEL-MAP_SOOT', 'Map-plain']
resources = {}
for name in metadata:
    path = ROOT / f'assets/Shaders/BLGL/Crater/{name}.shader.meta'
    uuid = json.loads(path.read_text('utf8'))['uuid']
    resources[uuid.replace('-', '_')] = {'uuid': uuid, 'shader': f'Shaders/BLGL/Crater/{name}.shader',
                                        'metadata': path.relative_to(ROOT).as_posix()}
warm_closed = [i for i, line in enumerate(lines, 1)
               if '[Script] [CombatWarmup] restored completed=true' in line]
assert len(warm_closed) == 1, warm_closed
closed = next(i for i, line in enumerate(lines, 1)
              if i > warm_closed[0] and line.endswith('[Script] [LoadingFlow] Closed'))
compiled = []
pattern = re.compile(r'Succeed to compile shader \[([^\]]+)\],defines \[([^\]]*)\]')
for number, line in enumerate(lines, 1):
    match = pattern.search(line)
    if not match:
        continue
    path, raw_defines = match.groups()
    for identity, resource in resources.items():
        if identity not in path:
            continue
        compiled.append({'line': number, 'timestamp': line[1:24], 'path': path,
                         'defines': raw_defines.split(';'), **resource})
        break
targets = []
for row in compiled:
    defines = set(row['defines'])
    ordinary = row['line'] > closed and row['path'].endswith('.vs') and 'INSTANCED' not in defines
    scatter = row['shader'].endswith('/Scatter.shader')
    missing = ('POINTLIGHT' in defines or 'SURFACE_SHADOW_ONLY' in defines) if scatter else '_shadow_' in row['path']
    if not ordinary or not missing:
        continue
    old_flag = 'INSTANCED' if scatter else 'USE_INSTANCE_COLOR'
    expected = defines | {old_flag}
    prior = [candidate for candidate in compiled if candidate['line'] < closed
             and candidate['shader'] == row['shader'] and candidate['path'].endswith('.vs')
             and set(candidate['defines']) == expected]
    assert prior, row
    targets.append({**row, 'loadingCounterpart': prior[0], 'extraLoadingDefine': old_flag})
assert len(targets) == 6, targets
scene = ROOT / 'assets/Scenes/Crater.xml'
scatter_groups = Counter()
for component in ET.parse(scene).iter('component'):
    if component.get('type') != 'StaticModelGroup':
        continue
    attributes = {a.get('name'): a.get('value') for a in component.findall('attribute')}
    material = attributes.get('Material', '').removeprefix('Material;')
    material_path = ROOT / 'assets' / material
    surface = ET.parse(material_path).getroot().find('surfaceshader')
    if surface is not None and surface.get('name') == 'Shaders/BLGL/Crater/Scatter.shader':
        scatter_groups[(attributes['Model'].removeprefix('Model;'), material,
                        attributes.get('Cast Shadows', 'false'))] += 1
report = {'manifest': '8d107d95', 'qaPort': 4483, 'loadingClosedLine': closed,
          'missingOrdinaryVariants': targets,
          'scatterScene': {'groups': sum(scatter_groups.values()), 'modelMaterialShadowTuples': len(scatter_groups),
                           'tuples': [{'model': key[0], 'material': key[1], 'castShadows': key[2], 'chunks': count}
                                      for key, count in sorted(scatter_groups.items())]},
          'inputHashes': {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in [LOG, scene] + [ROOT / v['metadata'] for v in resources.values()]},
          'boundary': 'Successful compile logs identify variants and event order, not compilation duration. '
                      'Scene XML counts authored groups, not visible groups or runtime vertex-layout equivalence. '
                      'This diagnosis does not attribute all sustained battle CPU time.'}
out = ROOT / 'docs/migration/evidence/map-warmup-source-evidence.json'
out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(json.dumps({'variants': len(targets), 'closedLine': closed,
                  'scatterAuthoredGroups': sum(scatter_groups.values()),
                  'scatterModelMaterialShadowTuples': len(scatter_groups)}))
