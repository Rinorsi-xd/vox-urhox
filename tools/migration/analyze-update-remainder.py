"""Recompute archived Update remainder without starting the game."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DETAILED = ROOT / 'docs/migration/evidence/performance-trial-sections-match-1792173507902'
COARSE = ROOT / 'docs/migration/evidence/performance-fixed-step-pipeline-match-1792176317849'
FIXED = ['combat.BeforeStep', 'world.Step', 'combat.AfterStep']
PRESENTATION = ['combatView.Update', 'effects.Update', 'hud.Update']
AUDIO = ['weaponAudio.Update', 'drivingAudio.Update', 'feedbackAudio.Update']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def analyze():
    summary = json.loads((DETAILED / 'drive-sections-summary.json').read_text())
    detailed = []
    all_names, identities = set(), []
    for line in (DETAILED / 'drive-sections.jsonl').read_text().splitlines():
        record = json.loads(line)
        assert record['dropped'] == 0
        identities.append(record['sourceIdentity'])
        names = record['names']
        all_names.update(names)
        for frame in record['frames']:
            if not summary['firstFrame'] <= frame['frame'] <= summary['lastFrame']:
                continue
            scopes = {names[row[0] - 1]: row for row in frame['values']}
            def inclusive(name):
                return scopes[name][2]
            remainder = inclusive('update.production') - sum(inclusive(name) for name in FIXED)
            presentation = {name: inclusive(name) for name in PRESENTATION}
            audio = {name: inclusive(name) for name in AUDIO}
            residual = remainder - sum(presentation.values())
            assert residual >= 0 and all(row[3] >= 0 for row in scopes.values())
            detailed.append({'frame': frame['frame'], 'updateMs': inclusive('update.production'),
                             'fixedMs': sum(inclusive(name) for name in FIXED),
                             'remainderMs': remainder, 'presentationMs': presentation,
                             'otherRemainderMs': residual, 'audioUpdateMs': audio})
    assert all(identity == identities[0] for identity in identities)
    assert [row['frame'] for row in detailed] == list(range(6, 253))
    assert len(detailed) == summary['frames'] == 247
    totals = {'updateMs': 0, 'fixedMs': 0, 'remainderMs': 0, 'presentationMs': 0,
              'otherRemainderMs': 0, 'audioUpdateMs': 0}
    for row in detailed:
        for key in totals:
            totals[key] += sum(row[key].values()) if isinstance(row[key], dict) else row[key]
    assert totals['updateMs'] == totals['fixedMs'] + totals['remainderMs']
    assert totals['remainderMs'] == totals['presentationMs'] + totals['otherRemainderMs']
    summary_rows = {row['name']: row for row in summary['rows']}
    assert totals['updateMs'] == summary_rows['update.production']['inclusiveMs']
    for name in PRESENTATION + AUDIO:
        field = 'presentationMs' if name in PRESENTATION else 'audioUpdateMs'
        assert sum(row[field][name] for row in detailed) == summary_rows[name]['inclusiveMs']

    coarse_summary = json.loads((COARSE / 'frame-pipeline-summary.json').read_text())
    coarse = []
    for line in (COARSE / 'frame-pipeline.jsonl').read_text().splitlines():
        record = json.loads(line)
        frame = record['frame']
        if not coarse_summary['afterFrame'] < frame['frame'] <= coarse_summary['throughFrame']:
            continue
        assert record['dropped'] == frame['droppedEvents'] == 0
        assert not frame['partialStart'] and not frame['partialEnd']
        scopes = frame['scopes']
        exclusive = {name: row['selfMs'] for name, row in scopes.items()}
        exclusive['unassignedWall'] = frame['unscopedWallMs']
        assert sum(exclusive.values()) == frame['wallMs']
        assert scopes['main.Update']['inclusiveMs'] == scopes['main.Update']['selfMs'] + sum(
            scopes[name]['inclusiveMs'] for name in ['fixed.BeforeStep', 'fixed.WorldStep', 'fixed.AfterStep'])
        if frame['wallMs'] > 50:
            coarse.append({'frame': frame['frame'], 'wallMs': frame['wallMs'],
                           'fixedSteps': scopes['fixed.BeforeStep']['calls'],
                           'dominantExclusive': max(exclusive, key=exclusive.get), 'exclusiveMs': exclusive})
    assert len(coarse) == 32
    return {'verification': 'PASS', 'detailedFrames': len(detailed), 'detailedTotalsMs': totals,
            'detailedMeanMs': {key: value / len(detailed) for key, value in totals.items()},
            'presentationShareOfRemainder': totals['presentationMs'] / totals['remainderMs'],
            'detailedTopRemainderFrames': sorted(detailed, key=lambda row: row['remainderMs'], reverse=True)[:12],
            'coarseLongFrameDominantCounts': dict(Counter(row['dominantExclusive'] for row in coarse)),
            'coarseLongFrameStepCounts': dict(Counter(row['fixedSteps'] for row in coarse)),
            'coarseLongFrames': coarse, 'detailedFrameRows': detailed,
            'inputSha256': {str(path.relative_to(ROOT)): digest(path) for path in [
                DETAILED / 'drive-sections.jsonl', DETAILED / 'drive-sections-summary.json',
                COARSE / 'frame-pipeline.jsonl', COARSE / 'frame-pipeline-summary.json']},
            'boundary': 'Independent arithmetic on two distinct archived observed runs. No new hardware, current-package timing, GC causality or optimization gain. Presentation roots are disjoint within Update by archived TrialSession call structure; audio rows are already inside otherRemainder and must not be added again. Coarse dominant scope is an observed wall owner, not proof of its internal stall cause.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), 'Refusing to overwrite evidence'
    result = analyze()
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: result[key] for key in ['verification', 'detailedMeanMs',
          'presentationShareOfRemainder', 'coarseLongFrameDominantCounts', 'coarseLongFrameStepCounts']}))
