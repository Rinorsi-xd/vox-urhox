"""Build one OFL repair glyph; never copy a Windows system font into assets."""
import hashlib
import io
import json
import sys
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/font-tooling'))
from fontTools import subset
from fontTools.ttLib import TTFont

COMMIT='8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5'
BASE=f'https://raw.githubusercontent.com/google/fonts/{COMMIT}/ofl/notosanssymbols2/'
def fetch(name):
    request=urllib.request.Request(BASE+name,headers={'User-Agent':'VoxelCraft-font-migration'})
    with urllib.request.urlopen(request,timeout=45) as response:return response.read()
def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    original=fetch('NotoSansSymbols2-Regular.ttf')
    license_bytes=fetch('OFL.txt')
    assert b'SIL OPEN FONT LICENSE Version 1.1' in license_bytes
    font=TTFont(io.BytesIO(original),recalcTimestamp=False)
    original_name=font['name'].getDebugName(1)
    original_glyph=font.getBestCmap()[0x271a]
    original_outline=font['glyf'][original_glyph].compile(font['glyf'])
    options=subset.Options();options.recalc_timestamp=False;options.notdef_outline=True
    builder=subset.Subsetter(options=options);builder.populate(unicodes=[0x271a]);builder.subset(font)
    # A distinct family avoids Reserved Font Name concerns for this modified font.
    for record in font['name'].names:
        replacement={1:'Vox Repair Symbols',2:'Regular',3:'VoxRepairSymbols-Regular-1',
                     4:'Vox Repair Symbols Regular',6:'VoxRepairSymbols-Regular',
                     16:'Vox Repair Symbols',17:'Regular'}.get(record.nameID)
        if replacement:record.string=replacement.encode(record.getEncoding())
    output=ROOT/'assets/Fonts/VoxRepairSymbols-Regular.ttf';font.save(output)
    with TTFont(output,recalcTimestamp=False) as check:
        assert set(check.getBestCmap())=={0x271a}
        glyph=check.getBestCmap()[0x271a]
        assert check['glyf'][glyph].compile(check['glyf'])==original_outline
        assert check['glyf'][glyph].numberOfContours>0
        assert output.stat().st_size<16000
        units=check['head'].unitsPerEm
        metrics={'units':units,'advance':check['hmtx'][glyph][0],
                 'ascent':check['hhea'].ascent,'descent':check['hhea'].descent,
                 'glyphs':len(check.getGlyphOrder()),'codepoints':['U+271A']}
    (ROOT/'assets/Fonts/VoxRepairSymbols-OFL.txt').write_bytes(license_bytes)
    report={'upstreamFamily':original_name,'repository':'https://github.com/google/fonts',
            'commit':COMMIT,'sourceURL':BASE+'NotoSansSymbols2-Regular.ttf',
            'licenseURL':BASE+'OFL.txt','license':'SIL Open Font License 1.1',
            'sourceSHA256':sha(original),'licenseSHA256':sha(license_bytes),
            'output':'Fonts/VoxRepairSymbols-Regular.ttf','outputSHA256':sha(output.read_bytes()),
            'outputBytes':output.stat().st_size,'metrics':metrics,'outlineUnchanged':True,
            'conversion':'fontTools Unicode subset U+271A only; renamed family; original Noto outline and metrics retained.',
            'scope':'Only endless repair icon. Windows native uses installed Segoe UI Symbol without bundling Microsoft data. Web/mobile Noto is a substitute, not pixel parity with Windows H5.'}
    (ROOT/'assets/Fonts/VoxRepairSymbols-PROVENANCE.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
