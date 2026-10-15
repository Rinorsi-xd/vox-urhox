"""Partition immutable map data so runtime decoding has bounded work units."""
from pathlib import Path
import json
import copy


def build(root, source=None, namespace='Crater'):
    root = Path(root)
    if source is None:
        source = json.loads((root/'tools/migration/crater-source/Manifest.json').read_text('utf-8'))['layout']
    layout = copy.deepcopy(source)
    heights = layout['terrain'].pop('heights')
    if isinstance(heights, dict):
        heights = [heights[str(i)] for i in range(len(heights))]
    blocks = layout.pop('blocks')
    out = root/'assets'/namespace/'Layout'
    out.mkdir(exist_ok=True)
    parts = []
    files = set()
    for field, values, count in [('heights', heights, 4096), ('blocks', blocks, 64)]:
        for first in range(0, len(values), count):
            name = f'{field}-{first//count:03d}.json'
            payload = json.dumps(values[first:first+count], ensure_ascii=False, separators=(',', ':'))
            (out/name).write_text(payload, encoding='utf-8');files.add(name)
            parts.append({'field': field, 'first': first+1, 'count': min(count, len(values)-first),
                          'path': namespace+'/Layout/'+name})
    # Only remove previously generated pieces in this exact output directory.
    for field in ('heights', 'blocks'):
        for old in out.glob(field+'-[0-9][0-9][0-9].json'):
            if old.name not in files:
                old.unlink();Path(str(old)+'.meta').unlink(missing_ok=True)
    layout['dataParts'] = {'version': 1, 'heights': len(heights), 'blocks': len(blocks), 'parts': parts}
    (root/'assets'/namespace/'Layout.json').write_text(json.dumps(layout, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    # Reassemble from written files to check ordering, values and completeness.
    merged = {'heights': [], 'blocks': []}
    for part in parts:
        assert part['first'] == len(merged[part['field']])+1
        merged[part['field']].extend(json.loads((root/'assets'/part['path']).read_text('utf-8')))
    assert merged['heights'] == heights and merged['blocks'] == blocks
    return {'parts': len(parts), 'heights': len(heights), 'blocks': len(blocks),
            'max_part_bytes': max((out/name).stat().st_size for name in files)}


if __name__ == '__main__':
    print(json.dumps(build(Path(__file__).resolve().parents[2])))
