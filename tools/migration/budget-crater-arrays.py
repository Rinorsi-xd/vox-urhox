"""Build terrain arrays from the frozen export with a bounded decoded footprint."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / '.tmp/crater-baseline-2026-10-13/assets/Crater'
SIZE = 1024

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def mip_bytes(size):
    return sum(max(1, size >> i) ** 2 * 4 for i in range(size.bit_length()))

def main():
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text('utf8'))
    records = []
    for kind in ('albedo', 'nra'):
        for layer in range(6):
            source = SOURCE / f'{kind}-{layer}.png'
            target = ROOT / 'assets/Crater' / f'{kind}-{layer}.bin'
            with Image.open(source) as image:
                assert image.size == (2048, 2048), f'Unexpected frozen layer: {source}'
                original = image.convert('RGBA')
                # All exported samples are linear. RGB in nra encodes normal/roughness;
                # preserve channel order and alpha height/AO without gamma conversion.
                reduced = Image.merge('RGBA', tuple(channel.resize((SIZE, SIZE), Image.Resampling.BOX)
                                                    for channel in original.split()))
                reduced.save(target, format='PNG')
            with Image.open(target) as check:
                assert check.size == (SIZE, SIZE) and check.mode == 'RGBA'
            records.append({'source':str(source.relative_to(ROOT)),
                            'runtime':str(target.relative_to(ROOT)),
                            'source_sha256':digest(source),'runtime_sha256':digest(target),
                            'source_size':[2048,2048],'runtime_size':[SIZE,SIZE],
                            'download_bytes':target.stat().st_size})
    report = {'baseline':baseline['commit'],'layers':records,
              'before_array_mip_bytes':12*mip_bytes(2048),
              'after_array_mip_bytes':12*mip_bytes(SIZE),
              'scope':'RGBA terrain arrays only; same six materials, shader parameters and UV scale. Fine texture detail reduced. Excludes other textures, staging buffers and driver allocations.'}
    (ROOT / 'docs/migration/evidence/crater-array-budget.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
    print(json.dumps({k:v for k,v in report.items() if k!='layers'},indent=2))

if __name__ == '__main__':
    main()
