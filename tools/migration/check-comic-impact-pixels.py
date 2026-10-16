"""Crop eight real logical-viewport captures and reject blank/old ordinary text."""
from pathlib import Path
import hashlib,json,re,sys
from PIL import Image
folder=Path(sys.argv[1]);rows=[]
for width,height in [(1920,1080),(2400,1080),(1440,1080),(1333,600)]:
 for kind in ['no','bang']:
  name=f'{width}x{height}-{kind}';source=folder/f'{name}.png'
  image=Image.open(source).convert('RGB');pw,ph=image.size;k=min(pw/width,ph/height)*.92
  left,top=round((pw-width*k)/2),round((ph-height*k)/2)
  right,bottom=round((pw+width*k)/2),round((ph+height*k)/2)
  crop=image.crop((left,top,right,bottom))
  assert abs(crop.width/crop.height-width/height)<.008
  pixels=list(crop.getdata());red=sum(r>115 and g<90 and b<90 for r,g,b in pixels)
  white=sum(min(r,g,b)>191 for r,g,b in pixels);dark=sum(max(r,g,b)<26 for r,g,b in pixels)
  assert min(red,white,dark)>150,(name,red,white,dark)
  target=folder/f'{name}-viewport.png';crop.save(target)
  rows.append({'name':name,'physicalScreenshot':[pw,ph],'logicalViewport':[width,height],'crop':[left,top,right,bottom],'cropPixels':[crop.width,crop.height],'redPixels':red,'whitePixels':white,'darkPixels':dark,'screenshotSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'cropSha256':hashlib.sha256(target.read_bytes()).hexdigest()})
report={'status':'PASS','captures':rows,'boundary':'Real native raster of final production No/Bang at four logical aspect ratios fitted into one physical window. Crops retain actual raster; not true-device resolution, source pixel equality, natural opening or performance acceptance.'}
(folder/'pixels.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':'PASS','captures':len(rows)}))
