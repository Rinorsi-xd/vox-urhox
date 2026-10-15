"""Subset the frozen source GameFont without changing retained glyph geometry."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/font-tooling'))
from fontTools import subset
from fontTools.ttLib import TTFont


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    baseline = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
    reads = []

    def read(relative):
        data = (Path(baseline['snapshot']) / relative).read_bytes()
        assert digest(data) == baseline['files'][relative]['sha256'], relative
        reads.append({'source': relative, 'sha256': digest(data), 'bytes': len(data)})
        return data

    css = read('shared/css/style.css').decode('utf-8')
    assert 'ZCOOLQingKeHuangYou-Regular.woff2' in css
    read('shared/fonts/ZCOOLQingKeHuangYou-Regular.woff2')
    relative = 'shared/fonts/ZCOOLQingKeHuangYou-Regular.ttf'
    original_bytes = read(relative)
    original_path = Path(baseline['snapshot']) / relative
    original = TTFont(original_path, recalcTimestamp=False)
    intro = json.loads((ROOT / 'assets/Intro/Intro.json').read_text(encoding='utf-8'))
    epilogue = json.loads((ROOT / 'assets/Story/Boss/Epilogue.json').read_text(encoding='utf-8'))
    assert epilogue['source']['commit'] == baseline['commit']
    for relative, expected in epilogue['source']['files'].items():
        assert digest(read(relative)) == expected, relative
    comic_text = ''.join(scene.get('panel', {}).get('label', '') +
                         (scene.get('panel', {}).get('sfx') or [''])[0]
                         for scene in epilogue['data']['scenes'])
    required = '0123456789NO!砰轰——击毁已损毁出动繁荣秩序带薪年假加入星际前途维和先锋零件大师英雄成为战地机修师已扣款'
    text = required + ''.join(intro['caps'].values()) + comic_text
    cmap = original.getBestCmap()
    points = sorted(set(map(ord, text)))
    supported = [cp for cp in points if cp in cmap]
    assert all(ord(c) in supported for c in required)
    options = subset.Options()
    options.glyph_names = True
    options.hinting = True
    options.recalc_timestamp = False
    options.layout_features = ['*']
    options.name_IDs = ['*']
    options.name_languages = ['*']
    font = subset.load_font(str(original_path), options)
    operation = subset.Subsetter(options=options)
    operation.populate(unicodes=supported)
    operation.subset(font)
    output = ROOT / 'assets/Intro/Fonts/GameFont.ttf'
    output.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(output), options)
    imported = TTFont(output, recalcTimestamp=False)
    target_cmap = imported.getBestCmap()
    for cp in supported:
        a, b = cmap[cp], target_cmap[cp]
        assert original['hmtx'][a] == imported['hmtx'][b], f'Changed advance: {cp}'
        before = original['glyf'][a].getCoordinates(original['glyf'])
        after = imported['glyf'][b].getCoordinates(imported['glyf'])
        assert before == after, f'Changed outline: {cp}'
    license_text = '\n\n'.join(sorted({record.toUnicode() for record in original['name'].names if record.nameID in (0, 13, 14)}))
    assert license_text, 'Source font license metadata missing'
    (output.parent / 'LICENSE.txt').write_text(license_text + '\n', encoding='utf-8')
    data = {'game': 'Intro/Fonts/GameFont.ttf', 'glyphs': ''.join(map(chr, supported))}
    (output.parent / 'Font.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    evidence = {'result': 'PASS', 'baseline': baseline['commit'], 'reads': reads, 'original_bytes': len(original_bytes),
                'output_bytes': output.stat().st_size, 'output_sha256': digest(output.read_bytes()), 'verified_codepoints': len(supported),
                'retained_outlines_and_advances': True, 'policy': 'On-demand original GameFont subset for opening and epilogue comics; original copyright/license metadata retained'}
    (ROOT / 'docs/migration/evidence/intro-game-font-import.json').write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(evidence))


if __name__ == '__main__':
    main()
