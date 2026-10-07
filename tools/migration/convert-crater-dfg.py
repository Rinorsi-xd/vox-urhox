"""Convert the source Three.js half-float DFG table, without modifying H5.

16-bit fixed point packing allows linear sampling with < 1/65535 error and
avoids backend-specific half-float DDS loaders. This is data, not an art asset.
"""
import hashlib,json,re,struct
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path('D:/Rino_Project/Vox/three/vendor/three')
text=(SOURCE/'build/three.module.js').read_text('utf8')
data=re.search(r'const DATA = new Uint16Array\( \[([^]]+)\] \);',text)
assert data,'Source DFG table not found'
bits=[int(v,16) for v in re.findall(r'0x[0-9a-f]+',data[1])]
assert len(bits)==16*16*2
floats=[struct.unpack('<e',struct.pack('<H',v))[0] for v in bits]
fixed=[round(v*65535) for v in floats]
image=Image.new('RGBA',(16,16))
image.putdata([(fixed[i]//256,fixed[i]%256,fixed[i+1]//256,fixed[i+1]%256) for i in range(0,len(fixed),2)])
image.save(ROOT/'assets/Crater/dfg.png')
(ROOT/'docs/migration/THREE_LICENSE.txt').write_bytes((SOURCE/'LICENSE').read_bytes())
report={'source':'three/vendor/three/build/three.module.js','source_sha256':hashlib.sha256(text.encode()).hexdigest(),
        'values':len(floats),'max_decode_error':max(abs(a-b/65535) for a,b in zip(floats,fixed)),
        'orientation':'row 0 is source v=0; same raw row convention as crater texture exporter'}
(ROOT/'docs/migration/evidence/crater-dfg.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
print(json.dumps(report))
