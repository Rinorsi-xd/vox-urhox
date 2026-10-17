"""Independent, offline provenance and geometry verifier; never writes game files."""
import copy
import argparse
import hashlib
import json
import pathlib
import struct
import subprocess
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMMIT = "b276064942ae09c0227ec28d4cfda1d5ff006455"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8-sig"))


def check(condition, reason):
    if not condition:
        raise AssertionError(reason)


def close(a, b, reason):
    check(len(a) == len(b) and all(abs(x-y) <= 1e-9 for x, y in zip(a, b)), reason)


def multiply(a, b):
    w, x, y, z = a
    W, X, Y, Z = b
    return [w*W-x*X-y*Y-z*Z, w*X+x*W+y*Z-z*Y,
            w*Y-x*Z+y*W+z*X, w*Z+x*Y-y*X+z*W]


def rotate(q, v):
    return multiply(multiply(q, [0, *v]), [q[0], -q[1], -q[2], -q[3]])[1:]


def compose(parent, p, q, s):
    pp, pq, ps = parent
    offset = rotate(pq, [a*b for a, b in zip(p, ps)])
    return ([a+b for a, b in zip(pp, offset)], multiply(pq, q), [a*b for a, b in zip(ps, s)])


IDENTITY = ([0, 0, 0], [1, 0, 0, 0], [1, 1, 1])


def scene_meshes():
    found = {}

    def walk(node, parent):
        attrs = {a.attrib['name']: a.attrib['value'] for a in node.findall('attribute')}
        values = lambda key, default: list(map(float, attrs.get(key, default).split()))
        world = compose(parent, values('Position', '0 0 0'), values('Rotation', '1 0 0 0'), values('Scale', '1 1 1'))
        for component in node.findall("component[@type='StaticModel']"):
            props = {a.attrib['name']: a.attrib['value'] for a in component.findall('attribute')}
            model = props.get('Model', '').split(';')[-1]
            if model.startswith('Crater/mesh-') and 279 <= int(model.split('-')[-1].split('.')[0]) <= 288:
                check(model not in found, 'duplicate scene model ' + model)
                found[model] = {'nodeId': int(node.attrib['id']), 'node': attrs.get('Name'),
                                'material': props.get('Material', '').split(';')[-1], 'transform': world}
        for child in node.findall('node'):
            walk(child, world)

    for node in ET.parse(ROOT / 'assets/Scenes/Crater.xml').getroot().findall('node'):
        walk(node, IDENTITY)
    return found


def model_info(blob, world):
    check(blob[:4] == b'UMDL', 'model signature')
    count, flags = struct.unpack_from('<II', blob, 8)
    check(struct.unpack_from('<I', blob, 4)[0] == 1 and flags == 31, 'model vertex format')
    end = 24 + count*44
    buffers, index_count, index_size = struct.unpack_from('<III', blob, end)
    check(buffers == 1 and index_size in (2, 4) and index_count % 3 == 0, 'model indices')
    check(len(blob) == end+12+index_count*index_size+80, 'model bytes')
    digest = hashlib.sha256()
    p, q, s = world
    # Hash every indexed world-space coordinate in order, retaining winding.
    for k in range(index_count):
        index = struct.unpack_from('<H' if index_size == 2 else '<I', blob, end+12+k*index_size)[0]
        check(index < count, 'model index range')
        v = struct.unpack_from('<fff', blob, 24+44*index)
        v = rotate(q, [a*b for a, b in zip(v, s)])
        digest.update(struct.pack('<ddd', *(a+b for a, b in zip(p, v))))
    return {'triangles': index_count//3, 'bytes': len(blob), 'sha256': sha(blob),
            'worldIndexedPositionSha256': digest.hexdigest()}


def reference():
    baseline = read('docs/migration/baselines/' + COMMIT + '.json')
    required = ['shared/battle/outpost.js', 'shared/battle/outpostCollide.js',
                'shared/battle/craterGhosts.js', 'three/src/drive/testDrive.js']
    for relative in required:
        check(sha((pathlib.Path(baseline['snapshot']) / relative).read_bytes()) == baseline['files'][relative]['sha256'], 'frozen hash ' + relative)
    # Execute the real frozen source predicate and key function, not a reimplementation.
    js = r"""const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
    (async()=>{const root=process.argv[1];const {buildOutpostLayout}=await import(pathToFileURL(path.join(root,'shared/battle/outpost.js')));
    const {GHOST_BLOCKS,blockKey}=await import(pathToFileURL(path.join(root,'shared/battle/craterGhosts.js')));
    const source=fs.readFileSync(path.join(root,'three/src/drive/testDrive.js'),'utf8');
    const line=source.split(/\r?\n/).find(x=>x.includes('w.layout.blocks = w.layout.blocks.filter('));
    const predicate=line.match(/filter\( \( b \) => (.*) \);/)[1];
    const keep=new Function('rocks','GHOST_BLOCKS','blockKey','b','return '+predicate);
    const blocks=buildOutpostLayout().blocks;
    process.stdout.write(JSON.stringify({ghostKeys:[...GHOST_BLOCKS],blocks,skipBlocks:blocks.flatMap((b,i)=>keep(true,GHOST_BLOCKS,blockKey,b)?[]:[i+1])}));
    })().catch(e=>{console.error(e);process.exitCode=1});"""
    result = subprocess.run(['node', '-e', js, baseline['snapshot']], cwd=ROOT, capture_output=True, text=True, check=True)
    return baseline, json.loads(result.stdout)


def expected_sources(materials):
    expected = {}

    def walk(node, group, parent):
        q = node.get('q', [0, 0, 0, 1])
        world = compose(parent, node.get('p', [0, 0, 0]), [q[3], q[0], q[1], q[2]], node.get('s', [1, 1, 1]))
        for mesh in node.get('meshes', []):
            if materials[mesh['material']]['kind'] in ['fx', 'shield', 'glow']:
                continue
            p, q, s = world
            expected[mesh['model']] = {'group': group, 'node': node['name'], 'material': mesh['material'],
                                       'transform': ([-p[0], p[1], p[2]], [q[0], q[1], -q[2], -q[3]], s)}
        for child in node.get('children', []):
            walk(child, group, world)

    for group in ['rocks', 'debris']:
        walk(read('tools/migration/crater-source/' + group + '.json'), group, IDENTITY)
    return expected


def validate(data, baseline, ref, scene, sources, geometries):
    check(data['version'] == 1 and data['source']['commit'] == COMMIT, 'version / commit')
    check(data['source']['branch'] == baseline['branch'], 'branch')
    check(sorted(data['ghostKeys']) == sorted(ref['ghostKeys']), 'exact ghost keys')
    check(data['skipBlocks'] == ref['skipBlocks'], 'exact source runtime filter')
    check(data['source']['sceneSha256'] == sha((ROOT/'assets/Scenes/Crater.xml').read_bytes()), 'scene provenance')
    check(data['source']['materialsSha256'] == sha((ROOT/'assets/Crater/Materials.json').read_bytes()), 'materials provenance')
    for relative, digest in data['source']['files'].items():
        check(relative in baseline['files'], 'registered source ' + relative)
        current = (pathlib.Path(baseline['source']) / relative).read_bytes()
        frozen = (pathlib.Path(baseline['snapshot']) / relative).read_bytes()
        check(digest == sha(current), 'source provenance ' + relative)
        check(current.replace(b'\r\n', b'\n') == frozen.replace(b'\r\n', b'\n'), 'source baseline content ' + relative)
    check(len(data['meshes']) == len(sources) == len(scene) == 10, 'mesh coverage')
    check(sorted(m['model'] for m in data['meshes']) == sorted(sources), 'exact visual model set')
    for mesh in data['meshes']:
        key = mesh['model']; src = sources[key]; xml = scene[key]; geometry = geometries[key]
        check(mesh['group'] == src['group'] and mesh['node'] == src['node'] == xml['node'], 'group / node')
        check(mesh['nodeId'] == xml['nodeId'], 'scene node id')
        check(xml['material'] == 'Crater/material-' + str(src['material']) + '.xml', 'source material id')
        check(mesh['material'] in [src['material'], xml['material']], 'data material')
        for field, index in [('position', 0), ('rotation', 1), ('scale', 2)]:
            close(mesh[field], src['transform'][index], 'source ' + field)
            close(mesh[field], xml['transform'][index], 'scene ' + field)
        check(mesh['modelSha256'] == geometry['sha256'], 'all model bytes and indexed triangles')
        check(mesh['triangles'] == geometry['triangles'], 'triangle count')
    check(data['totals']['meshes'] == 10, 'mesh total')
    check(data['totals']['triangles'] == sum(g['triangles'] for g in geometries.values()), 'triangle total')
    check(data['totals']['modelBytes'] == sum(g['bytes'] for g in geometries.values()), 'model bytes total')
    check(159 not in data['skipBlocks'], 'active Hull159 perch retained')
    for i, block in enumerate(ref['blocks'], 1):
        if block['kind'] == 'bound':
            check(i not in data['skipBlocks'], 'boundary retained')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    baseline, ref = reference()
    data = read('assets/Crater/DrivingCollision.json')
    scene = scene_meshes(); sources = expected_sources(read('assets/Crater/Materials.json'))
    geometries = {key: model_info((ROOT/'assets'/key).read_bytes(), value['transform']) for key, value in scene.items()}
    verify = lambda candidate: validate(candidate, baseline, ref, scene, sources, geometries)
    verify(data)
    mutations = {
        'omit visual mesh': lambda d: d['meshes'].pop(),
        'wrong mesh path': lambda d: d['meshes'][0].update(model='Crater/mesh-278.bin'),
        'wrong transform': lambda d: d['meshes'][0]['position'].__setitem__(0, .25),
        'wrong winding or vertex bytes': lambda d: d['meshes'][0].update(modelSha256='0'*64),
        'triangle count': lambda d: d['meshes'][0].update(triangles=1),
        'retain obsolete rock': lambda d: d['skipBlocks'].pop(),
        'remove active perch': lambda d: d['skipBlocks'].append(159),
        'omit ghost': lambda d: d['ghostKeys'].pop(),
        'wrong source commit': lambda d: d['source'].update(commit='wrong'),
    }
    negative = []
    for label, mutate in mutations.items():
        candidate = copy.deepcopy(data); mutate(candidate)
        try:
            verify(candidate)
        except (AssertionError, KeyError):
            negative.append(label)
        else:
            raise AssertionError('negative control accepted: ' + label)
    key = data['meshes'][0]['model']; original = (ROOT/'assets'/key).read_bytes()
    for label in ['alter actual vertex', 'reverse actual winding']:
        changed = bytearray(original)
        if label == 'alter actual vertex':
            struct.pack_into('<f', changed, 24, struct.unpack_from('<f', changed, 24)[0] + .5)
        else:
            count = struct.unpack_from('<I', changed, 8)[0]; end = 24+count*44
            size = struct.unpack_from('<I', changed, end+8)[0]; start = end+12
            a = bytes(changed[start:start+size]); b = bytes(changed[start+size:start+size*2])
            changed[start:start+size] = b; changed[start+size:start+size*2] = a
        altered_geometries = dict(geometries)
        altered_geometries[key] = model_info(changed, scene[key]['transform'])
        check(altered_geometries[key]['worldIndexedPositionSha256'] != geometries[key]['worldIndexedPositionSha256'], 'negative geometry must change')
        try:
            validate(data, baseline, ref, scene, sources, altered_geometries)
        except AssertionError:
            negative.append(label)
        else:
            raise AssertionError('negative control accepted: ' + label)
    result = {'status': 'PASS', 'sourceCommit': COMMIT, 'rawBlocks': len(ref['blocks']),
                      'skippedBlocks': len(ref['skipBlocks']), 'retainedBlocks': len(ref['blocks'])-len(ref['skipBlocks']),
                      'totals': data['totals'], 'indexedWorldTriangles': geometries,
                      'negativeControls': negative,
                      'boundary': 'Offline source/runtime filter and all model bytes/ordered triangles verified. Does not claim Bullet contact, EnginePit runtime isolation, frame rate, or mobile acceptance.'}
    if args.output:
        args.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
