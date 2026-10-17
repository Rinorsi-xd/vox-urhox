"""Trace the archived measured GC spike without reclassifying residual time as GC."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / 'docs/migration/evidence/performance-live/2026-10-16T12-40-29-802Z-45796-4d6ff5'
log = source / 'session-33786b7521c16556b4a19f61.jsonl'
identity = json.loads((source / 'identity.json').read_text('utf8'))
rows = {}
selected = []
def accept(row, priority, origin):
    frame = row.get('frame')
    if frame is None or not 3909 <= frame <= 3930:
        return
    previous = rows.get(frame)
    if previous and previous['priority'] >= priority:
        return
    stages = {stage['name']: {'ms': stage['ms'], 'selfMs': stage['selfMs'], 'calls': stage['calls']}
              for stage in row.get('stages', []) if stage['name'].startswith(('gc.', 'app.ReleaseSettledAssets'))}
    rows[frame] = {'priority': priority, 'origin': origin, 'frame': frame,
                   **{key: row[key] for key in ['frameMs', 'wallMs', 'scriptMs', 'steps', 'luaKiB', 'topStage', 'topMs'] if key in row},
                   'context': row.get('context', {}), 'gcStages': stages}
for line in log.read_text('utf8').splitlines():
    record = json.loads(line)
    for row in record.get('recent', []):
        accept(row, 0, 'recent compact')
    for row in record.get('frameSamples', []):
        accept(row, 1, 'sample compact')
    if record.get('type') in ['sample', 'slow_frame', 'error_frame']:
        accept(record, 2, record['type'])
    if record.get('type') == 'slow_frame' and record.get('frame') == 3924:
        selected.append(record)
assert len(selected) == 1
spike = selected[0]
gc = next(row for row in spike['stages'] if row['name'] == 'gc.Step')
assert spike['frameMs'] == 88 and spike['steps'] == 0 and gc['ms'] == 44 and gc['calls'] == 1
assert not any(row['name'] == 'app.ReleaseSettledAssets' for row in spike['stages'])
source_hashes = {}
for name in ['core/CollectionCycle.lua', 'render/RenderTargetLifetime.lua', 'app/HangarApp.lua']:
    current = hashlib.sha256((root / 'scripts' / name).read_bytes()).hexdigest()
    recorded = identity['identity']['scripts'][name]
    source_hashes[name] = {'currentSha256': current, 'recordedSha256': recorded, 'matchesRecorded': current == recorded}
result = {'status': 'PASS', 'sourceLog': str(log.relative_to(root)),
          'sourceLogSha256': hashlib.sha256(log.read_bytes()).hexdigest(),
          'sourceIdentitySha256': hashlib.sha256((source / 'identity.json').read_bytes()).hexdigest(),
          'manifest': identity.get('servedManifest'), 'targetCommit': identity['identity']['targetCommit'],
          'sourceHashes': source_hashes, 'frames': [rows[frame] for frame in sorted(rows)],
          'measuredSpike': {'frame': 3924, 'frameMs': 88, 'scriptMs': 60, 'gcStepMs': 44, 'steps': 0},
          'inference': 'No ReleaseSettledAssets parent label plus the two production Step call sites supports RenderTargetLifetime.Update. Queue size, texture identity and internal GC subphase were not recorded; they cannot be reconstructed.'}
out = root / 'docs/migration/evidence/gc-retirement-2026-10-16'
out.mkdir(exist_ok=True)
(out / 'analysis.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', 'utf8')
(out / 'measured-frame-3924.json').write_text(json.dumps(spike, ensure_ascii=False, indent=2) + '\n', 'utf8')
print(json.dumps({'status': result['status'], 'measuredSpike': result['measuredSpike'],
                  'sourceHashes': source_hashes, 'rows': len(rows), 'output': str(out)}, ensure_ascii=False))
