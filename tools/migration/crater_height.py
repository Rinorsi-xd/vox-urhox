"""Lossless CPU height grid from the exported H5 near-terrain vertices."""
from pathlib import Path
import json
import struct


def build(root):
    root = Path(root)
    tree = json.loads((root / 'tools/migration/crater-source/terrain.json').read_text('utf-8'))
    n, origin, step = 640, -320, 1
    heights = [None] * (n + 1)**2
    files = []

    def visit(node):
        assert node['p'] == [0, 0, 0] and node['q'] == [0, 0, 0, 1] and node['s'] == [1, 1, 1]
        for mesh in node['meshes']:
            path = root / 'assets' / mesh['model']
            data = path.read_bytes()
            magic, buffers, count, mask, morph_start, morph_count = struct.unpack_from('<4s5I', data)
            assert (magic, buffers, mask, morph_start, morph_count) == (b'UMDL', 1, 31, 0, 0)
            for k in range(count):
                native_x, y, z = struct.unpack_from('<3f', data, 24 + k * 44)
                x = -native_x  # Return to source coordinates before indexing.
                i, j = round((x-origin)/step), round((z-origin)/step)
                assert 0 <= i <= n and 0 <= j <= n
                assert x == origin+i*step and z == origin+j*step
                index = i*(n+1)+j
                assert heights[index] is None or heights[index] == y, 'Chunk seam differs'
                heights[index] = y
            files.append(mesh['model'])
        for child in node['children']:
            visit(child)

    visit(tree)
    assert all(h is not None for h in heights), 'Incomplete near terrain'
    payload = struct.pack('<4sI3f', b'VHF1', n, origin, origin, step)
    payload += struct.pack(f'<{len(heights)}f', *heights)
    output = root / 'assets/Crater/VisualHeight.bin'
    output.write_bytes(payload)
    return {'source_meshes': len(files), 'samples': len(heights), 'bytes': len(payload),
            'minimum': min(heights), 'maximum': max(heights)}


if __name__ == '__main__':
    print(json.dumps(build(Path(__file__).resolve().parents[2])))
