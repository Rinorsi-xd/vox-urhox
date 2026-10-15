"""Review captured native images/material JSON without changing raw evidence."""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

directory = Path(sys.argv[1]).resolve()
raw_names = ['manifest.json', 'result.json', 'shell-native.json', 'stdout.txt', 'stderr.txt']
raw_names += [p.name for p in directory.glob('*.png') if p.name not in ['shell-contact-sheet.png', 'shell-difference-crops.png']]
raw_names += [p.name for p in directory.glob('*.material.json')]
def hashes():
    return {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in sorted(raw_names)}
before = hashes()
details = json.loads((directory / 'shell-native.json').read_text(encoding='utf-8-sig'))
manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8-sig'))
validator = json.loads((directory / 'result.json').read_text(encoding='utf-8-sig'))
def differences(a, b, prefix=''):
    if isinstance(a, dict) and isinstance(b, dict):
        rows = []
        for key in sorted(a.keys() | b.keys()):
            rows.extend(differences(a.get(key), b.get(key), prefix + '/' + key))
        return rows
    return [] if a == b else [{'path': prefix, 'base': a, 'variant': b}]
materials, pixels, crops = [], [], []
for preset in ['scorpion', 'fox', 'trooper', 'manta']:
    base = json.loads((directory / (preset + '-base.material.json')).read_text())
    variant = json.loads((directory / (preset + '-variant.material.json')).read_text())
    delta = differences(base, variant)
    materials.append({'preset': preset, 'differences': delta,
                      'pass': [row['path'] for row in delta] == ['/shaderParameters/base_color']})
    image = Image.open(directory / (preset + '-shared.png')).convert('RGB')
    for state in ['repaint', 'xray', 'restored']:
        other = Image.open(directory / (preset + '-' + state + '.png')).convert('RGB')
        difference = ImageChops.difference(image, other)
        box = difference.getbbox()
        changed = sum(1 for pixel in difference.get_flattened_data() if max(pixel) > 2)
        pixels.append({'preset': preset, 'state': state, 'changedPixelsOver2': changed, 'bbox': box,
                       'pass': changed > 0 if state != 'restored' else None,
                       'boundary': 'Restored pose pixels are informational; exact restored bindings are verified by native assertions.' if state == 'restored' else 'Real repaint/xray must change rendered pixels.'})
        if box and state in ['repaint', 'xray']:
            x0, y0, x1, y1 = box
            box = (max(0, x0 - 10), max(0, y0 - 10), min(image.width, x1 + 10), min(image.height, y1 + 10))
            for label, sample in [('shared', image), (state, other)]:
                crop = sample.crop(box);crop.thumbnail((400, 240))
                crops.append((preset + ' ' + label + ' vs ' + state, crop))
captures = details['captures']
sheet = Image.new('RGB', (1200, ((len(captures) + 2) // 3) * 245), '#11151c')
draw = ImageDraw.Draw(sheet)
for index, capture in enumerate(captures):
    image = Image.open(directory / (capture['name'] + '.png')).convert('RGB')
    image.thumbnail((390, 218));x, y = (index % 3) * 400, (index // 3) * 245
    sheet.paste(image, (x, y + 22));draw.text((x + 5, y + 4), capture['name'], fill='white')
sheet.save(directory / 'shell-contact-sheet.png')
sheet = Image.new('RGB', (800, ((len(crops) + 1) // 2) * 270), '#11151c');draw = ImageDraw.Draw(sheet)
for index, (label, crop) in enumerate(crops):
    x, y = (index % 2) * 400, (index // 2) * 270
    draw.text((x + 5, y + 4), label, fill='white');sheet.paste(crop, (x, y + 24))
sheet.save(directory / 'shell-difference-crops.png')
errors = [error for phase in validator['phases'].values() for error in phase.get('errors', [])]
spikes = [error for error in errors if error['message'].startswith('Frame time spike:')]
report = {'rawHashes': before, 'productionAndFixtureDrift': manifest['changedDuringRun'],
          'functionalAssertions': validator['test_assertions'], 'complete': details['complete'],
          'nativeMaterials': materials, 'nativePixelDifferences': pixels,
          'clonesCreated': details['clonesCreated'], 'leasesRetired': details['clonesDisposed'],
          'damage': details['damage'], 'rawValidatorResult': validator['result'],
          'rawValidatorSummary': validator['summary'], 'frameSpikesOver100ms': len(spikes),
          'allValidatorErrorsAreFrameSpikes': len(errors) == len(spikes),
          'boundary': 'Exact saved native Material JSON and actual captured pixels. Lease zero-ref disposal observation, not an external allocation profiler. Whole validator FAIL remains FAIL; screenshot captures and synchronous fixture building are included. No Web/mobile/whole-game parity or performance acceptance.'}
report['functionalAndPixelReview'] = 'PASS' if details['complete'] and not manifest['changedDuringRun'] and all(row['pass'] is not False for row in materials + pixels) else 'FAIL'
assert before == hashes(), 'Raw evidence changed during independent image/material review'
(directory / 'independent-review.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'review': report['functionalAndPixelReview'], 'validator': validator['result'],
                  'materialCases': len(materials), 'pixelPairs': len(pixels), 'spikesOver100ms': len(spikes),
                  'contactSheet': str(directory / 'shell-contact-sheet.png')}, indent=2))
