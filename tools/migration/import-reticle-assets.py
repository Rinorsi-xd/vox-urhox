import hashlib
import json
import secrets
import shutil
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.tmp/font-tooling'))
from fontTools.ttLib import TTFont
baseline = json.loads((root / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8-sig'))
source = Path(baseline['snapshot']) / 'shared'
records = []
def ensure_meta(target):
    meta = Path(str(target) + '.meta')
    if not meta.exists():
        meta.write_text(json.dumps({'uuid': secrets.token_urlsafe(18)}, indent=2) + '\n', encoding='utf-8')

for weight in ('Bold', 'Medium'):
    original = source / f'fonts/ChakraPetch/ChakraPetch-{weight}.woff2'
    target = root / f'assets/Fonts/ChakraPetch-{weight}.ttf'
    font = TTFont(original, recalcTimestamp=False)
    font.flavor = None
    font.save(target)
    ensure_meta(target)
    records.append({'source': str(original), 'target': str(target), 'sourceSha256': hashlib.sha256(original.read_bytes()).hexdigest(), 'targetSha256': hashlib.sha256(target.read_bytes()).hexdigest()})
shutil.copyfile(source / 'fonts/ChakraPetch/OFL.txt', root / 'assets/Fonts/ChakraPetch-OFL.txt')
ensure_meta(root / 'assets/Fonts/ChakraPetch-OFL.txt')
icons = root / 'assets/UI/WeaponIcons'
icons.mkdir(exist_ok=True)
for original in sorted((source / 'assets/ui/weapon-icons').glob('*.png')):
    target = icons / original.name
    shutil.copyfile(original, target)
    records.append({'source': str(original), 'target': str(target), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
(root / 'docs/migration/evidence/reticle-assets.json').write_text(json.dumps({'baseline': baseline, 'assets': records}, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Imported {len(records)} frozen HUD assets')
