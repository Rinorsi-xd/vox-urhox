"""Restore old animated exports from original material/GLB authoring data.

Read-only source checkout; retains geometry IDs, UVs, instances and resource paths.
Also usable as an independent export contract check with --check.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / 'tools/migration/crater-source'
SOURCE = Path(json.loads((ROOT/'docs/migration/outgame-baseline.json').read_text('utf8'))['snapshot'])/'shared/assets/maps/crater'


def close(a, b):
    return len(a) == len(b) and all(math.isclose(x, y, abs_tol=1e-7) for x, y in zip(a, b))


def run(check=False):
    manifest_path = EXPORT / 'Manifest.json'
    manifest = json.loads(manifest_path.read_text('utf8'))
    source_manifest = json.loads((SOURCE / 'manifest.json').read_text('utf8'))
    assert manifest['version'] == source_manifest['version'], 'Source/export versions differ; re-export first'
    material_path = SOURCE / source_manifest['materials']
    table = json.loads(material_path.read_text('utf8'))
    changed_colors, changed_poses, checked_colors, checked_poses = [], [], 0, 0
    for i, material in enumerate(manifest['materials'], 1):
        if material['kind'] not in ('glow', 'fx', 'shield'):
            continue
        info = table[material['name']]
        # mapMaterials.js emitLevel; Color.setRGB is already linear.
        level = .45 * max(info.get('emit') or 1, 0) ** .7
        if material['kind'] != 'glow':
            level *= info.get('alpha', .5)
        color = [v * level for v in info.get('emitColor', info['color'])]
        checked_colors += 1
        if not close(material['color'], color):
            changed_colors.append({'id': i, 'name': material['name'], 'before': material['color'], 'after': color})
            material['color'] = color
    source_hashes = {material_path.name: hashlib.sha256(material_path.read_bytes()).hexdigest()}
    pending = []
    expected_poses = 0
    for entry in manifest['roots']:
        source_path = SOURCE / (entry['id'] + '.glb')
        if not source_path.exists():
            continue # generated terrain/far/scatter do not have authored GLBs
        raw = source_path.read_bytes()
        magic, version, total = struct.unpack_from('<4sII', raw)
        assert magic == b'glTF' and version == 2 and total == len(raw)
        length, kind = struct.unpack_from('<II', raw, 12)
        assert kind == 0x4e4f534a
        gltf = json.loads(raw[20:20+length])
        authored = {}
        for node in gltf['nodes']:
            if not node.get('extras', {}).get('dyn'):
                continue
            # THREE.PropertyBinding.sanitizeNodeName, as used by GLTFLoader.
            name = re.sub(r'[\[\].:/]', '', re.sub(r'\s', '_', node['name']))
            assert name not in authored, 'Ambiguous source dynamic name: ' + name
            assert 'matrix' not in node, 'Matrix rest pose needs explicit decomposition'
            authored[name] = node
        export_path = EXPORT / Path(entry['file']).name
        exported = json.loads(export_path.read_text('utf8'))
        seen = set()

        def visit(node):
            nonlocal checked_poses
            if node.get('dyn'):
                src = authored[node['name']]
                assert src['extras']['dyn'] == node['dyn']
                rest = {'p': src.get('translation', [0, 0, 0]), 'q': src.get('rotation', [0, 0, 0, 1]), 's': src.get('scale', [1, 1, 1])}
                changed = [key for key in rest if not close(node[key], rest[key])]
                if changed:
                    changed_poses.append({'module': entry['id'], 'name': node['name'], 'fields': changed})
                    node.update(rest)
                checked_poses += 1
                seen.add(node['name'])
            for child in node['children']:
                visit(child)

        visit(exported)
        assert seen == set(authored), 'Missing source dynamics: ' + entry['id']
        expected_poses += len(authored)
        pending.append((export_path, exported))
        source_hashes[source_path.name] = hashlib.sha256(raw).hexdigest()
    assert checked_poses == expected_poses and expected_poses > 0
    report = {'checked_colors': checked_colors, 'checked_poses': checked_poses,
              'changed_colors': changed_colors, 'changed_poses': changed_poses, 'source_hashes': source_hashes}
    if check:
        assert not changed_colors and not changed_poses, 'Animated export differs from original authoring data'
    else:
        # Validate all modules before the first write.
        for path, data in [(manifest_path, manifest), *pending]:
            path.write_text(json.dumps(data, ensure_ascii=False), encoding='utf8')
        (ROOT / 'docs/migration/evidence/crater-authoring-repair.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print(json.dumps({'result':'PASS', 'checked_colors':checked_colors, 'checked_poses':checked_poses,
                      'changed_colors':len(changed_colors), 'changed_poses':len(changed_poses)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    run(parser.parse_args().check)
