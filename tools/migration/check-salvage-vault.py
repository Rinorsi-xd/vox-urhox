"""Compare frozen JS vault callbacks to actual Lua rules and event consumers."""
import json
import subprocess
from g5_offline import ROOT as root, execute, hashes, negatives

subprocess.run(['node', 'tools/migration/check-salvage-vault-source.cjs'], check=True)
fixtures = json.loads((root / '.tmp/source-salvage-vault-fixtures.json').read_text(encoding='utf-8'))
files = ['scripts/salvage/Run.lua', 'scripts/salvage/RunRules.lua']
before = hashes(files)
test = ['tools/migration/check-salvage-vault.lua']
checks = execute(test, {'fixtures': fixtures})
negative = negatives(test, [
    ('scripts/salvage/RunRules.lua', 'local slow=math.abs(state.speed)<2', 'local slow=math.abs(state.speed)<=2', 'case 1 frame 5 crack progress'),
    ('scripts/salvage/RunRules.lua', 'self:Emit(\'vaultStart\');', '', 'case 1 frame 3 source effect order/parameters'),
    ('scripts/salvage/RunRules.lua', 'if s.crack>=8 then', 'if s.crack>=9 then', 'case 1 frame 7 camera trauma'),
    ('scripts/salvage/Run.lua', 'self.speed=math.sqrt(dx*dx+dz*dz)/math.max(.001,dt)', 'self.speed=math.abs(u.vehicle.speed)', 'sideways-forward-speed-zero real entry source XZ speed'),
], {'fixtures': fixtures})
assert before == hashes(files), 'Production inputs changed during check'
report = {'result': 'PASS', 'checks': checks,
          'runtime': 'Lua 5.4 via lupa', 'sourceCommit': fixtures['commit'],
          'sourceHashes': fixtures['sourceHashes'], 'productionHashes': before,
          'sourceCases': len(fixtures['cases']), 'sourceFrames': sum(len(c['frames']) for c in fixtures['cases']),
          'sourceEntryFrames': len(fixtures['entry']), 'negativeControls': negative,
          'resources': hashes(['assets/UI/Outgame.json', 'assets/Salvage/RunData.json']),
          'testInputs': hashes(test + ['tools/migration/check-salvage-vault.py',
              'tools/migration/check-salvage-vault-source.cjs', 'tools/migration/g5_offline.py', 'tools/migration/g5-offline-imports.lua']),
          'boundary': 'Unchanged frozen JS _searchStep/update vs actual Lua RunRules.SearchStep, Run.Events and Run.AfterStep. Actual positions derive entry speed; physics/UI/FX/audio are adapters. Audio omitted, no GPU, browser, account, visual or performance acceptance.'}
out = root / 'docs/migration/evidence/salvage-vault-hoist-2026-10-16.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'negativeControls': len(negative), 'evidence': str(out)}))
