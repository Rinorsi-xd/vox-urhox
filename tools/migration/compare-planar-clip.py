"""Contact sheet of actual GPU controls; all columns use each row's same crop."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops

root=Path(__file__).resolve().parents[2]
evidence=root/'docs/migration/evidence'
cases=['opaque','transparent','thruster','hover','tilted-thruster']
phases=['above','partial-unclipped','partial','below']
sheet=Image.new('RGB',(1200,5*260+30),'#171a20')
draw=ImageDraw.Draw(sheet)
for col,label in enumerate(['Above floor','Crossing / clip OFF','Crossing / clip ON','Below floor / clip ON']):
    draw.text((col*300+8,8),label,fill='white')
for row,name in enumerate(cases):
    frames=[Image.open(evidence/f'planar-clip-{name}-{phase}.png').convert('RGB') for phase in phases]
    mask=Image.new('L',frames[0].size)
    for frame in frames:
        signal=ImageChops.lighter(ImageChops.lighter(*frame.split()[:2]),frame.split()[2])
        mask=ImageChops.lighter(mask,signal.point(lambda n:255 if n>8 else 0))
    bounds=mask.getbbox()
    assert bounds,f'No positive control for {name}'
    x0,y0,x1,y1=bounds
    crop=(max(0,x0-15),max(0,y0-15),min(frames[0].width,x1+15),min(frames[0].height,y1+15))
    for col,frame in enumerate(frames):
        thumbnail=frame.crop(crop);thumbnail.thumbnail((280,225),Image.Resampling.LANCZOS)
        x=col*300+(300-thumbnail.width)//2;y=row*260+60
        sheet.paste(thumbnail,(x,y));draw.text((col*300+8,row*260+38),name,fill='#b4c3d7')
sheet.save(evidence/'planar-clip-sheet.png')
