"""Lossless RG8 KTX1 packing of source building AO/direct-light atlases.

Source mapModules.js disables mipmaps for these atlases. Ground keeps its mips.
KTX1 layout: https://registry.khronos.org/KTX/specs/1.0/ktxspec.v1.html
Default stages candidates under .tmp; --apply installs verified packing.
"""
from pathlib import Path
import argparse, hashlib, json, struct, shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SIGNATURE=b'\xabKTX 11\xbb\r\n\x1a\n'
SIDECAR='''<?xml version="1.0"?>
<texture><address coord="u" mode="clamp"/><address coord="v" mode="clamp"/><filter mode="bilinear"/><mipmap enable="false"/></texture>
'''
def rgba_to_rg(image):
    r,g,*_=image.convert('RGB').split()
    # LA is only a byte interleave here, not an image encoding or GPU format.
    return Image.merge('LA',(r,g)).tobytes()
def pack(w,h,data):
    assert w%2==0 and len(data)==w*h*2, 'rows must already meet KTX 4-byte alignment'
    # GL_UNSIGNED_BYTE, GL_RG, GL_RG8; no arrays, one face, one mip, no metadata.
    header=SIGNATURE+struct.pack('<13I',0x04030201,0x1401,1,0x8227,0x822B,0x8227,w,h,0,0,1,1,0)
    return header+struct.pack('<I',len(data))+data
def run(apply):
    if apply:
        raise RuntimeError("RG8 KTX is not supported by shipping Web; preserve the PNG runtime atlases")
    manifest=json.loads((ROOT/'tools/migration/crater-source/Manifest.json').read_text('utf8'))
    names=sorted({p for m in manifest['materials'] for k,p in m['textures'].items() if k=='tBake'})
    assert len(names)==5 and manifest['ground'] not in names
    pending=[];records=[]
    for name in names:
        live=ROOT/'assets'/name
        source=ROOT/'tools/migration/crater-source/bakes'/live.name
        chosen=live if live.exists() else source
        with Image.open(chosen) as im: w,h=im.size;data=rgba_to_rg(im)
        payload=pack(w,h,data)
        assert payload[68:]==data and struct.unpack_from('<I',payload,64)[0]==len(data)
        target=(ROOT/'assets' if apply else ROOT/'.tmp/crater-bakes')/Path(name).with_suffix('.ktx')
        # Verify every path before any replacement/move of generated assets.
        for path in (live,source,target): path.resolve().relative_to(ROOT)
        pending.append((live,source,target,payload))
        old_bytes=sum(max(1,w>>i)*max(1,h>>i)*4 for i in range(max(w,h).bit_length()))
        records.append({'source':name,'runtime':str(Path(name).with_suffix('.ktx')).replace('\\','/'),
            'width':w,'height':h,'source_png_bytes':chosen.stat().st_size,
            'old_rgba_mip_bytes':old_bytes,'rg8_bytes':len(data),'ktx_bytes':len(payload),
            'rg_sha256':hashlib.sha256(data).hexdigest(),'ktx_sha256':hashlib.sha256(payload).hexdigest()})
    for live,source,target,payload in pending:
        target.parent.mkdir(parents=True,exist_ok=True);temp=target.with_suffix('.ktx.packing')
        temp.write_bytes(payload);temp.replace(target)
        target.with_suffix('.xml').write_text(SIDECAR,'utf8')
        if not apply:
            shutil.copyfile(live if live.exists() else source,target.with_suffix('.png'))
        if apply and live.exists():
            source.parent.mkdir(parents=True,exist_ok=True);live.replace(source)
            # The old PNG resource UUID is no longer referenced by runtime.
            Path(str(live)+'.meta').unlink(missing_ok=True)
    report={'applied':apply,'format':'KTX1 RG8_UNORM, linear, one mip',
        'old_rgba_mip_bytes':sum(r['old_rgba_mip_bytes'] for r in records),
        'rg8_bytes':sum(r['rg8_bytes'] for r in records),'records':records,
        'limits':'GPU payload from verified dimensions/format, not driver allocation or total VRAM; no geographic streaming claim'}
    label='packed' if apply else 'candidate'
    (ROOT/f'docs/migration/evidence/crater-bakes-{label}.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
    print(json.dumps({k:v for k,v in report.items() if k!='records'},indent=2))
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true')
    run(parser.parse_args().apply)
