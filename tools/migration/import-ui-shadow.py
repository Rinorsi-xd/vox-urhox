"""Bake the Gaussian rectangle coverage used by the original CSS box-shadow.

This is a filter kernel, not replacement artwork. Nine-slice sampling preserves
the corners while scaling only constant rows/columns; no runtime blur pass.
"""
from pathlib import Path
from math import erf, sqrt
from PIL import Image
import hashlib
import json

def main():
    root = Path(__file__).resolve().parents[2]
    sigma, extent, size = 16, 48, 193

    def cdf(x):
        return (1 + erf(x / (sigma * sqrt(2)))) / 2

    coverage = [cdf(x + .5 - extent) - cdf(x + .5 - (size - extent)) for x in range(size)]
    image = Image.new('RGBA', (size, size))
    image.putdata([(255, 255, 255, round(255 * coverage[x] * coverage[y]))
                   for y in range(size) for x in range(size)])
    path = root / 'assets/UI/SourceBoxShadow.png'
    image.save(path, optimize=True)
    report = {'source': 'shared/css/style.css .bay-new-menu box-shadow: 0 16px 36px rgba(0,0,0,.5)',
              'algorithm': 'Separable Gaussian convolution of rectangular coverage, sigma=blur/2',
              'sigma': sigma, 'size': size, 'slice': [0, 96, 97, 193], 'margin': extent,
              'png_bytes': path.stat().st_size, 'rgba_bytes': size * size * 4,
              'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    (root / 'docs/migration/evidence/ui-shadow-import.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
