"""Compare deterministic native render fixtures captured before/after GPU migration.

Baseline is the previous CPU implementation, not proof of full H5 visual parity.
Particle-only images avoid hiding a disappeared effect in a whole-map average.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[2]
folder = root / 'docs/migration/evidence'
rows = []
for pose in ('origin', 'teleport', 'wrap'):
    before = np.asarray(Image.open(folder / f'dust-baseline-{pose}.png').convert('RGB')).astype(float)
    after = np.asarray(Image.open(folder / f'dust-gpu-{pose}.png').convert('RGB')).astype(float)
    assert before.shape == after.shape, 'render dimensions changed'
    mask = np.maximum(before.max(axis=2), after.max(axis=2)) > 3
    error = np.abs(after - before)
    # Native CPU vertex colors used 8-bit quantization; GPU fade is full precision.
    relative_error = float(error.sum() / max(1, before.sum()))
    row = dict(pose=pose, particle_pixels=int(mask.sum()),
               foreground_mae=float(error[mask].mean()), relative_rgb_error=relative_error,
               before_energy=float(before.sum()), after_energy=float(after.sum()),
               passed=bool(mask.sum() > 100 and relative_error < .12 and error[mask].mean() < 2))
    rows.append(row)
report = dict(result='PASS' if all(r['passed'] for r in rows) else 'FAIL',
              scope='Seeded native CPU/GPU mote render equivalence; not full H5/map parity', poses=rows)
(folder / 'crater-dust-render-comparison.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(0 if report['result'] == 'PASS' else 1)
