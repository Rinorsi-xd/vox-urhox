"""Same-camera H5/native sun views, plus actual visible on/off effect metrics."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parents[2]/'docs/migration/evidence'
sheet=Image.new('RGB',(1440,804),'#161920');draw=ImageDraw.Draw(sheet)
records=[]
for col,(prefix,title) in enumerate([('crater-h5-post-map-sun','H5'),('crater-native-map-sun','UrhoX')]):
    arrays=[]
    for row,state in enumerate(['on','off']):
        im=Image.open(root/f'{prefix}-{state}.png').convert('RGB')
        arrays.append(np.asarray(im,dtype=np.int16))
        im.thumbnail((720,380));sheet.paste(im,(col*720,row*402+22))
        draw.text((col*720+10,row*402+4),f'{title} shafts {state}',fill='white')
    delta=arrays[0]-arrays[1]
    records.append(dict(renderer=title,maximum_increase=int(delta.max()),mean_increase=float(delta.mean()),
                        changed_pixels=int(np.count_nonzero(np.max(np.abs(delta),axis=2)>2))))
sheet.save(root/'crater-shafts-comparison.png')
(root/'crater-shafts-visible.json').write_text(json.dumps(dict(records=records,
    limits='Actual full map on/off captures. Geometry lighting, cloud noise and particles differ between engines; not a pixel parity claim.'),indent=2),encoding='utf8')
print(json.dumps(records,indent=2))
