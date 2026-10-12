"""Create light-channel fixtures or compare the production map captures."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fixtures',action='store_true')
args=parser.parse_args()
if args.fixtures:
    for name,g in [('shadow',0),('clear',255)]:
        Image.new('RGB',(4,4),(255,g,255)).save(ROOT/f'.tmp/crater-direct-{name}.png')
else:
    out=ROOT/'docs/migration/evidence';report={}
    for key in ['indirect','sun']:
        a=np.array(Image.open(out/f'crater-direct-{key}-shadow.png').convert('RGB')).astype(float)
        b=np.array(Image.open(out/f'crater-direct-{key}-clear.png').convert('RGB')).astype(float)
        d=abs(a-b)
        report[key]={'mean_255':float(d.mean()),'max_255':float(d.max()),'pixels_changed':int(np.any(d>1,axis=2).sum())}
    report['pass']=report['indirect']['max_255']<=1 and report['sun']['mean_255']>.1
    (out/'crater-direct-light-pixels.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
    print(json.dumps(report));assert report['pass'],'Baked visibility leaked into indirect light or lost direct shading'
