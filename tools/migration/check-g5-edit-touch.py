"""Frozen source callbacks versus actual production Lua, with behavioral negatives."""
import json
import hashlib
from pathlib import Path
import subprocess
from g5_offline import ROOT as root, execute, hashes, negatives

baseline = json.loads((root / 'docs/migration/baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json').read_text(encoding='utf-8'))
source_hashes = {}
for name in ['three/src/battle/endlessEdit.js', 'three/src/salvage/salvageRun.js']:
    digest = hashlib.sha256((Path(baseline['snapshot']) / name).read_bytes()).hexdigest()
    assert digest == baseline['files'][name]['sha256'], f'Frozen source changed: {name}'
    source_hashes[name] = digest
production = ['scripts/endless/Edit.lua', 'scripts/ui/EndlessEditBar.lua', 'scripts/salvage/Run.lua',
              'scripts/salvage/RunRules.lua', 'scripts/salvage/Loot.lua', 'scripts/ui/SalvageLootMotion.lua',
              'scripts/construction/BuildEditor.lua', 'scripts/construction/BuildStretch.lua', 'scripts/controls/BuildInput.lua']
before = hashes(production)
source = json.loads(subprocess.check_output(['node', 'tools/migration/check-g5-edit-source.cjs'], text=True, encoding='utf-8'))
edit_fixtures = ['tools/migration/check-g5-edit-touch.lua', 'tools/migration/check-g5-source-edit.lua']
pickup_fixtures = ['tools/migration/check-g5-pickup.lua']
data = {'sourceEdit': source}
check_names = execute(edit_fixtures, data) + execute(pickup_fixtures)
negative = negatives(edit_fixtures, [
    ('scripts/endless/Edit.lua', 'inventory.hotbar[empty]=id', 'inventory.hotbar[empty]=false', 'purchase fills first empty slot'),
    ('scripts/endless/Edit.lua', 'if inventory.hotbar[i]==id then return result end', 'if false then return result end', 'repeat purchase adds stock without duplicate shortcut'),
    ('scripts/endless/Edit.lua', 'e.history.undoStack={};e.history.redoStack={};', '', 'reset clears both history stacks'),
    ('scripts/endless/Edit.lua', 'self.build.controls:Cancel();BuildStretch.Cancel(e)', 'BuildStretch.Cancel(e)', 'reset cancels real pointer and touch holds'),
    ('scripts/salvage/Run.lua', 'prompt and not prompt.blocked and prompt or nil', 'prompt or nil', 'touch blocked-prompt filter 3'),
], data)
negative += negatives(pickup_fixtures, [
    ('scripts/salvage/Run.lua', 'math.min(1.6,.25+mass/40)', 'math.min(1.5,.25+mass/40)', 'heavy pickup uses 1.6 cap without resetting spring velocity'),
])
# Ensure the new source comparison can independently reject a changed callback.
negative += negatives(edit_fixtures, [
    ('scripts/endless/Edit.lua', 'inventory.hotbar[empty]=id', 'inventory.hotbar[empty]=false', 'gapped source callback 1 hotbar'),
], data | {'sourceOnly': True})
assert before == hashes(production), 'Production inputs changed during check'
report = {'result': 'PASS', 'checks': check_names,
          'runtime': 'Lua 5.4 via lupa', 'sourceCommit': baseline['commit'],
          'sourceHashes': source_hashes, 'productionHashes': before,
          'sourceCases': len(source['cases']), 'sourceCallbackFrames': sum(len(c['frames']) for c in source['cases']),
          'negativeControls': negative,
          'resources': hashes(['assets/UI/Outgame.json', 'assets/Salvage/RunData.json']),
          'testInputs': hashes(edit_fixtures + pickup_fixtures + ['tools/migration/check-g5-edit-touch.py',
              'tools/migration/check-g5-edit-source.cjs', 'tools/migration/g5_offline.py', 'tools/migration/g5-offline-imports.lua']),
          'boundary': 'Frozen JS fillShop button callbacks/reset/rebuild/refresh consumed against actual Lua Edit/BuildEditor and shop callbacks. Pickup expectations remain manual; salvage JS is hash-bound only in this runner. UI/native edges adapted; unused hoisted imports fail on access. No Enter/Leave lifecycle, GPU, browser, actual account, natural full waves/extraction, visual or performance acceptance.'}
out = root / 'docs/migration/evidence/g5-edit-touch-hoist-2026-10-16.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': report['result'], 'checks': len(report['checks']), 'sourceCases': report['sourceCases'],
                  'negativeControls': len(negative), 'evidence': str(out)}))
