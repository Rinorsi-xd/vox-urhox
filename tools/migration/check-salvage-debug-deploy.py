"""Execute the real lobby, UI departure callbacks and app entry inventory gate."""
import json
import re
from g5_offline import ROOT, execute, hashes, negatives

paths = ['scripts/app/SalvageLobby.lua', 'scripts/ui/SalvagePage.lua', 'scripts/app/HangarApp.lua',
         'scripts/salvage/StashRules.lua', 'scripts/app/DebugActions.lua']
before = hashes(paths)
actual = {name.removeprefix('scripts/').removesuffix('.lua').replace('/', '.') for name in paths}
imports = set()
for name in paths:
    imports.update(re.findall(r'''require\s*\(?\s*['"]([^'"]+)['"]''', (ROOT / name).read_text(encoding='utf-8')))
data = {'imports': sorted(imports - actual),
        'resources': {name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8'))
                      for name in ['UI/Outgame.json', 'UI/SalvageRules.json']}}
fixtures = ['tools/migration/check-salvage-debug-deploy.lua']
checks = execute(fixtures, data)
rejected = negatives(fixtures, [
    (paths[0], 'if self.app.debugEnabled==true then return {} end', 'if false then return {} end', 'button gate debug=true'),
    (paths[0], 'if self.app.debugEnabled==true then return {} end', 'if self.app.debugEnabled then return {} end', 'button gate debug=1'),
    (paths[1], 's.app.salvageLobby:DeploymentShortfall()', 's.app.salvageLobby:Shortfall()', 'callback gate debug=true'),
    (paths[1], 'local shortage=Stash.ShortfallInfo(lobby:DeploymentShortfall(usage))', 'local shortage=Stash.ShortfallInfo(short)', 'button gate debug=true'),
    (paths[2], 'pairs(self.salvageLobby:DeploymentShortfall())', 'pairs(self.salvageLobby:Shortfall())', 'app gate debug=true'),
], data)
assert before == hashes(paths), 'Production changed during tests'
report = {'result': 'PASS', 'checks': checks, 'negativeControls': rejected, 'productionHashes': before,
          'boundary': 'Actual complete Lua modules and entry methods executed; UI widgets, native vehicle spec and scene-loading endpoint adapted. No Web input, gameplay, account, persistence, GPU or performance claim.'}
output = ROOT / 'docs/migration/evidence/salvage-debug-deploy-offline.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'checks': len(checks), 'negativeControls': len(rejected), 'evidence': str(output)}))
