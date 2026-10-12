"""Bake the frozen H5 CSS image filters once, avoiding runtime filter passes."""
from pathlib import Path
from PIL import Image
import math

root = Path(__file__).resolve().parents[2]
output = root / 'assets/UI/Modes/Filtered'
output.mkdir(parents=True, exist_ok=True)

def bake(name, state, saturation, brightness, contrast=1, hue=0):
    angle = math.radians(hue)
    c, s = math.cos(angle), math.sin(angle)
    hue_matrix = (
        (.213 + c*.787 - s*.213, .715 - c*.715 - s*.715, .072 - c*.072 + s*.928),
        (.213 - c*.213 + s*.143, .715 + c*.285 + s*.140, .072 - c*.072 - s*.283),
        (.213 - c*.213 - s*.787, .715 - c*.715 + s*.715, .072 + c*.928 + s*.072),
    )
    sat_matrix = tuple(tuple(weight*(1-saturation) + (saturation if i == j else 0)
                             for j, weight in enumerate((.213, .715, .072))) for i in range(3))
    matrix = tuple(tuple(sum(hue_matrix[i][k]*sat_matrix[k][j] for k in range(3))*brightness*contrast
                         for j in range(3)) for i in range(3))
    coefficients = tuple(value for row in matrix for value in (*row, 255*(1-contrast)*.5))
    with Image.open(root / f'assets/UI/Modes/{name}.jpg') as image:
        image.convert('RGB').convert('RGB', coefficients).save(output / f'{name}-{state}.jpg', quality=92)

for name in ('elimination', 'conquest', 'escort', 'test', 'crater'):
    bake(name, 'idle', .55, .55)
    bake(name, 'hover', .85, .8)
    bake(name, 'selected', 1, .95)
for name in ('test', 'crater'):
    bake(name, 'map', .9, 1, 1.05)
bake('crater', 'story', .5, .5, hue=170)
bake('crater', 'story-hover', .8, .72, hue=170)
print(f'Baked {len(list(output.glob("*.jpg")))} source CSS states into {output}')
