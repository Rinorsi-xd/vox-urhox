from pathlib import Path
import json
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[2]/'docs/migration/evidence'
a=np.array(Image.open(root/'environment-cache-before.png').convert('RGB')).astype(int)
b=np.array(Image.open(root/'environment-cache-after.png').convert('RGB')).astype(int)
d=np.abs(a-b)
report={'max_255':int(d.max()),'mean_255':float(d.mean()),'pixels_over_1':int((d.max(axis=2)>1).sum())}
(root/'environment-cache-pixels.json').write_text(json.dumps(report,indent=2)+'\n','utf8')
print(report);assert report['max_255']<=1,'Active environment changed when clearing reusable bake cache'
