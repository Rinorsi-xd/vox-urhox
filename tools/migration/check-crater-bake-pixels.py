from pathlib import Path
import json
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[2]/'docs/migration/evidence';report={}
for view in ('fort','ship','interior'):
    a=np.array(Image.open(root/f'crater-bakes-{view}-original.png').convert('RGB')).astype(int)
    b=np.array(Image.open(root/f'crater-bakes-{view}-rg8.png').convert('RGB')).astype(int)
    d=np.abs(a-b)
    report[view]={'max_255':int(d.max()),'mean_255':float(d.mean()),'pixels_over_1':int((d.max(axis=2)>1).sum())}
(root/'crater-bakes-pixels.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
print(json.dumps(report));assert all(v['max_255']<=1 for v in report.values()),'RG8 atlas changed rendered lighting'
