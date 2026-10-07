"""Recover omitted normalScale from the original GLBs; source stays read-only."""
import argparse, hashlib, json, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('D:/Rino_Project/Vox/shared/assets/props')
def run(check):
    source_materials, hashes = {}, {}
    for name in ('boulder_a', 'boulder_b', 'boulder_c', 'boulder_d', 'pebble', 'bush'):
        file = SOURCE / (name + '.glb'); raw = file.read_bytes()
        assert raw[:4] == b'glTF'
        length, kind = struct.unpack_from('<II', raw, 12); assert kind == 0x4e4f534a
        gltf = json.loads(raw[20:20+length]); hashes[file.name] = hashlib.sha256(raw).hexdigest()
        for mesh in gltf['meshes']:
            for primitive in mesh['primitives']:
                assert 'TANGENT' not in primitive['attributes'], 'Authored tangent stream now requires export'
        for material in gltf['materials']:
            texture = material['normalTexture']
            assert texture.get('texCoord', 0) == 0 and not texture.get('extensions'), 'Normal UV transform requires export'
            scale = texture.get('scale', 1)
            source_materials[material['name']] = [scale, scale]
    path = ROOT / 'tools/migration/crater-source/Manifest.json'
    data = json.loads(path.read_text('utf8')); count = 0
    for material in data['materials']:
        if material['kind'] != 'scatter': continue
        scale = source_materials[material['name']]; count += 1
        assert 'normal' in material['textures']
        if check: assert material['normalScale'] == scale
        else: material['normalScale'] = scale
    assert count == 8
    if not check: path.write_text(json.dumps(data, ensure_ascii=False), 'utf8')
    report = {'materials': count, 'normalScale': source_materials, 'sourceHashes': hashes,
              'basis': 'All source primitives omit TANGENT; Three uses UV derivative frame'}
    (ROOT/'docs/migration/evidence/crater-scatter-authoring.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
    print('PASS: 8 original scatter normal-map contracts')
if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true')
    run(parser.parse_args().check)
