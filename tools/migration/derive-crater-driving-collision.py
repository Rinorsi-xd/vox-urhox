"""Derive real H5 driving filters and native visual-mesh collision descriptors."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import xml.etree.ElementTree as ET

BASELINE = 'b276064942ae09c0227ec28d4cfda1d5ff006455'
SOURCE_FILES = ['three/src/drive/testDrive.js', 'shared/battle/outpost.js',
                'shared/battle/outpostCollide.js', 'shared/battle/craterGhosts.js',
                'shared/drive/terrain.js', 'shared/combat/tuning.js']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def attrs(node):
    return {a.get('name'): a.get('value') for a in node.findall('attribute')}


def multiply(a, b):
    w, x, y, z = a
    v, i, j, k = b
    return [w*v-x*i-y*j-z*k, w*i+x*v+y*k-z*j,
            w*j-x*k+y*v+z*i, w*k+x*j-y*i+z*v]


def rotate(q, p):
    return multiply(multiply(q, [0, *p]), [q[0], -q[1], -q[2], -q[3]])[1:]


def compose(parent, local):
    p, q, s = parent
    lp, lq, ls = local
    # Node world TRS cannot represent sheared matrices; fail instead of guessing.
    assert max(s)-min(s) < 1e-9 or max(abs(v) for v in lq[1:]) < 1e-9, 'Sheared transform'
    offset = rotate(q, [lp[i]*s[i] for i in range(3)])
    return ([p[i]+offset[i] for i in range(3)], multiply(q, lq),
            [s[i]*ls[i] for i in range(3)])


def model_info(data):
    assert data[:4] == b'UMDL'
    vertices = struct.unpack_from('<I', data, 8)[0]
    assert struct.unpack_from('<I', data, 12)[0] == 31
    offset = 24 + vertices*44
    buffers, indices, index_size = struct.unpack_from('<III', data, offset)
    assert buffers == 1 and indices % 3 == 0 and index_size in (2, 4)
    return vertices, indices//3


def check_numbers(a, b):
    if isinstance(a, (float, int)) and isinstance(b, (float, int)):
        assert abs(a-b) < 1e-12, (a, b)
    elif isinstance(a, list):
        assert isinstance(b, list) and len(a) == len(b)
        for x, y in zip(a, b):
            check_numbers(x, y)
    elif isinstance(a, dict):
        assert isinstance(b, dict) and a.keys() == b.keys()
        for key in a:
            check_numbers(a[key], b[key])
    else:
        assert a == b, (a, b)


def derive(root, source):
    git = ['git', '-c', 'safe.directory='+source.as_posix(), '-C', str(source)]
    head = subprocess.check_output([*git, 'rev-parse', 'HEAD'], text=True).strip()
    assert head == BASELINE, 'Expected frozen H5 baseline '+BASELINE
    hashes = {}
    for name in SOURCE_FILES:
        current = (source/name).read_bytes()
        frozen = subprocess.check_output([*git, 'show', BASELINE+':'+name])
        assert current.replace(b'\r\n', b'\n') == frozen.replace(b'\r\n', b'\n'), \
            'Modified H5 baseline input: '+name
        hashes[name] = digest(current)
    # Execute the exact real entry-point statement, not a second handwritten filter.
    helper = r'''
      const fs=require('node:fs'),{pathToFileURL}=require('node:url');
      (async()=>{
        const root=process.argv[1];
        const {buildOutpostLayout}=await import(pathToFileURL(root+'/shared/battle/outpost.js'));
        const {GHOST_BLOCKS,blockKey}=await import(pathToFileURL(root+'/shared/battle/craterGhosts.js'));
        const {TERRAIN}=await import(pathToFileURL(root+'/shared/combat/tuning.js'));
        const code=fs.readFileSync(root+'/three/src/drive/testDrive.js','utf8');
        const statement=code.split(/\r?\n/).find(s=>s.includes('w.layout.blocks = w.layout.blocks.filter('));
        if(!statement)throw Error('Missing real crater entry filter');
        const original=buildOutpostLayout().blocks,w={layout:{blocks:[...original]}};
        new Function('w','rocks','GHOST_BLOCKS','blockKey',statement)(w,true,GHOST_BLOCKS,blockKey);
        const retained=new Set(w.layout.blocks);
        console.log(JSON.stringify({blocks:original,ghostKeys:[...GHOST_BLOCKS],
          skipBlocks:original.flatMap((b,i)=>retained.has(b)?[]:[i+1]),
          friction:TERRAIN.friction,statement:statement.trim()}));
      })().catch(e=>{console.error(e);process.exitCode=1});
    '''
    actual = json.loads(subprocess.check_output(['node', '-e', helper, str(source)],
                                                text=True, encoding='utf-8'))
    layout = json.loads((root/'assets/Crater/Layout.json').read_text('utf-8'))
    blocks = [b for part in layout['dataParts']['parts'] if part['field'] == 'blocks'
              for b in json.loads((root/'assets'/part['path']).read_text('utf-8'))]
    check_numbers(actual.pop('blocks'), blocks)
    materials_path = root/'assets/Crater/Materials.json'
    materials = json.loads(materials_path.read_text('utf-8'))
    scene_path = root/'assets/Scenes/Crater.xml'
    scene = ET.parse(scene_path).getroot()
    meshes = []
    resources = json.loads((root/'assets/Crater/Resources.json').read_text('utf-8'))

    def visit(node, transform, group):
        a = attrs(node)
        local = (list(map(float, a.get('Position', '0 0 0').split())),
                 list(map(float, a.get('Rotation', '1 0 0 0').split())),
                 list(map(float, a.get('Scale', '1 1 1').split())))
        world = compose(transform, local)
        for component in node.findall('component'):
            if component.get('type') != 'StaticModel':
                continue
            c = attrs(component)
            model = c['Model'].split(';')[1]
            material = c['Material'].split(';')[1]
            index = int(Path(material).stem.split('-')[-1])
            if materials[index-1]['kind'] in ('fx', 'shield', 'glow'):
                continue
            assert model in resources, 'Driving mesh must reuse existing preload: '+model
            content = (root/'assets'/model).read_bytes()
            vertices, triangles = model_info(content)
            meshes.append({'group': group, 'nodeId': int(node.get('id')), 'node': a.get('Name'),
                           'model': model, 'material': material, 'position': world[0],
                           'rotation': world[1], 'scale': world[2], 'vertices': vertices,
                           'triangles': triangles, 'modelBytes': len(content),
                           'modelSha256': digest(content)})
        for child in node.findall('node'):
            visit(child, world, group)

    for node in scene.findall('node'):
        name = attrs(node).get('Name')
        if name in ('rocks', 'debris'):
            visit(node, ([0, 0, 0], [1, 0, 0, 0], [1, 1, 1]), name)
    assert meshes and {d['group'] for d in meshes} == {'rocks', 'debris'}
    return {'version': 1, 'source': {'commit': head, 'branch': '2026-10-15', 'files': hashes,
            'sceneSha256': digest(scene_path.read_bytes()),
            'materialsSha256': digest(materials_path.read_bytes()), 'filter': actual['statement']},
            'friction': actual['friction'], 'ghostKeys': actual['ghostKeys'],
            'skipBlocks': actual['skipBlocks'], 'meshes': meshes,
            'totals': {'meshes': len(meshes), 'triangles': sum(d['triangles'] for d in meshes),
                       'modelBytes': sum(d['modelBytes'] for d in meshes)}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=Path('D:/Rino_Project/Vox'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    data = derive(project, args.source.resolve())
    target = project/'assets/Crater/DrivingCollision.json'
    text = json.dumps(data, ensure_ascii=True, separators=(',', ':'))+'\n'
    if args.check:
        assert target.read_text('utf-8') == text, 'DrivingCollision.json is stale'
    else:
        target.write_text(text, encoding='utf-8', newline='\n')
    print(json.dumps({'result': 'PASS', **data['totals'], 'skipBlocks': len(data['skipBlocks']),
                      'sha256': digest(text.encode('utf-8'))}))
