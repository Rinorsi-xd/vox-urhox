"""Inspect actual rendered normal-map influence without modifying captures."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
import numpy as np
root=Path(__file__).resolve().parents[2]/'docs/migration/evidence'
sheet=Image.new('RGB',(1360,760));draw=ImageDraw.Draw(sheet);stats={}
for row,kind in enumerate(('rock','leaves')):
    frames=[]
    for col,state in enumerate(('flat','normal')):
        im=Image.open(root/f'crater-scatter-{kind}-{state}.png').convert('RGB')
        frames.append(np.array(im).astype(int));sheet.paste(im.resize((680,360)),(col*680,row*380+20))
        draw.text((col*680+10,row*380+4),kind+' / '+state,fill='white')
    delta=np.abs(frames[0]-frames[1]);changed=int((delta.max(axis=2)>1).sum())
    stats[kind]={'max_255':int(delta.max()),'changed_pixels':changed}
    assert changed>100,'Original normal map has no visible influence: '+kind
sheet.save(root/'crater-scatter-normal-comparison.png')
(root/'crater-scatter-pixels.json').write_text(json.dumps(stats,indent=2)+'\n','utf8')
print(stats)
