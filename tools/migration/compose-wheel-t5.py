"""Side-by-side real H5 ruler and native app T5 capture; no geometry/image stretching."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
evidence = root / 'docs/migration/evidence'
h5 = Image.open(evidence / 'wheel-t5-h5-ruler.jpg').convert('RGB')
native = Image.open(evidence / 'wheel-t5-native-tread.png').convert('RGB')
assert h5.size == (1280, 720) and native.size == (640, 460)
# Original H5 renderer's left viewport: x=0, y=180, w=640, h=460.
h5 = h5.crop((0, 180, 640, 640))
assert max(max(native.getextrema()[i]) for i in range(3)) > 80, 'Empty native capture'
canvas = Image.new('RGB', (1280, 580), '#142034')
canvas.paste(h5, (0, 64)); canvas.paste(native, (640, 64))
draw = ImageDraw.Draw(canvas)
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 23)
small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 18)
draw.text((24, 14), '原 H5 · T5 动力轮', font=font, fill='white')
draw.text((664, 14), 'UrhoX · 同一 T5 动力轮', font=font, fill='white')
draw.line((640, 0, 640, 524), fill='#74889e', width=2)
draw.text((24, 531), '同型号、同朝向、同正交比例；图中竖向为轮轴厚度。', font=small, fill='white')
draw.text((24, 556), '两端橡胶厚度约 2.715 米；保留各自材质，灯光环境不同。本图不作为材质一致性验收。', font=small, fill='#b9cadc')
canvas.save(evidence / 'wheel-t5-width-comparison.png')
print(evidence / 'wheel-t5-width-comparison.png')
