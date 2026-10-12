"""Import the frozen source's actual typography, icons and prefab artwork."""
from pathlib import Path
from PIL import Image
import json, sys, shutil, re
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/font-tooling'))
from fontTools.ttLib import TTFont
from fontTools.svgLib.path import parse_path
from fontTools.pens.recordingPen import RecordingPen
baseline=json.loads((root/'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
source=Path(baseline['snapshot'])/'shared'
font=TTFont(source/'fonts/AlimamaShuHeiTi/AlimamaShuHeiTi-Bold.woff2',recalcTimestamp=False)
font.flavor=None
font.save(root/'assets/Fonts/VoxIndustrial-Bold.ttf')
shutil.copyfile(source/'fonts/AlimamaShuHeiTi/LICENSE.txt',root/'assets/Fonts/VoxIndustrial-LICENSE.txt')
folder=root/'assets/UI/Prefabs'
folder.mkdir(exist_ok=True)
for file in (source/'assets/ui/prefabs').glob('*.jpg'): shutil.copyfile(file,folder/file.name)
for category in ('modes','salvage'):
    destination=root/'assets/UI'/category.title()
    destination.mkdir(exist_ok=True)
    for file in (source/'assets/ui'/category).glob('*.jpg'): shutil.copyfile(file,destination/file.name)
faces=root/'assets/UI/Faces'
faces.mkdir(exist_ok=True)
for file in (source/'assets/intro/face').glob('*.webp'):
    Image.open(file).save(faces/(file.stem+'.png'))
    old=faces/file.name
    if old.exists(): old.unlink()
paths=dict(re.findall(r"^\s*(\w+): '([^']+)'",(source/'ui/icons.js').read_text(encoding='utf-8'),re.M))
icons={}
for name,path in paths.items():
    pen=RecordingPen();parse_path(path,pen)
    icons[name]=[[op,*[round(v,6) for p in points for v in p]] for op,points in pen.value]
(root/'assets/UI/SourceIcons.json').write_text(json.dumps(icons,separators=(',',':')),encoding='utf-8')
print(f'Imported industrial font, {len(list(folder.glob("*.jpg")))} prefab images, {len(icons)} icons')
