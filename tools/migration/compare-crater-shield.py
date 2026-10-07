"""Build inspectable contact sheets from actual H5/native shield captures."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
import numpy as np
ROOT=Path(__file__).resolve().parents[2]/'docs/migration/evidence'
states=['intact','flash','ring','expired','low','dissolve','down','raise','raised']
w,h=510,270
sheet=Image.new('RGB',(w*3,(h+24)*3),(20,24,27));draw=ImageDraw.Draw(sheet)
for i,name in enumerate(states):
    x,y=i%3*w,i//3*(h+24)
    sheet.paste(Image.open(ROOT/f'crater-shield-{name}.png').convert('RGB').resize((w,h)),(x,y+24))
    draw.text((x+10,y+6),'UrhoX / '+name,fill='white')
sheet.save(ROOT/'crater-shield-states.png')
selected=['intact','flash','ring','dissolve','down','raise']
compare=Image.new('RGB',(w*2,(h+24)*len(selected)),(20,24,27));draw=ImageDraw.Draw(compare)
for row,name in enumerate(selected):
    for col,(label,prefix) in enumerate([('H5','crater-h5-post-shield-'),('UrhoX','crater-shield-')]):
        x,y=col*w,row*(h+24)
        compare.paste(Image.open(ROOT/(prefix+name+'.png')).convert('RGB').resize((w,h)),(x,y+24))
        draw.text((x+10,y+6),label+' / '+name,fill='white')
compare.save(ROOT/'crater-shield-comparison.png')
records=[]
for prefix in ['crater-h5-post-shield','crater-shield']:
    baseline=np.array(Image.open(ROOT/(prefix+'-intact.png')).convert('RGB')).astype(float)
    for name in ['flash','ring','low','dissolve','down','raise']:
        current=np.array(Image.open(ROOT/(prefix+'-'+name+'.png')).convert('RGB')).astype(float)
        delta=abs(current-baseline)
        records.append({'engine':prefix,'state':name,'changed_pixels_over_10':int(np.any(delta>10,axis=2).sum()),
                        'max_rgb_delta':float(delta.max()),'mean_rgb_delta':float(delta.mean())})
(ROOT/'crater-shield-visible.json').write_text(json.dumps({'scope':'Actual map states versus their own intact baseline; not pixel parity between engines','states':records},indent=2)+'\n','utf8')
