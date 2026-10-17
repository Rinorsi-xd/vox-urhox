"""Run frozen JS and real Lua stock-selection consumers without hardware."""
import json
import re
import subprocess
from g5_offline import ROOT, execute, hashes, negatives

golden = json.loads(subprocess.check_output(['node', 'tools/migration/check-endless-edit-stock-source.cjs'], encoding='utf-8'))
actual = ['endless.Edit', 'endless.Inventory', 'endless.Data', 'Config', 'parts.Defs',
          'construction.Inventory', 'construction.Blueprint', 'construction.BuildEditor',
          'construction.BuildStretch', 'construction.EditHistory', 'controls.BuildInput',
          'app.BuildSession', 'ui.InventoryPanel', 'ui.InventoryKeys', 'core.Rotations',
          'parts.Mounts', 'parts.Solid', 'construction.BuildClearance',
          'construction.BlueprintMigration', 'construction.LiveryData']
paths = ['scripts/' + name.replace('.', '/') + '.lua' for name in actual]
imports = set()
for name in paths:
    imports.update(re.findall(r'''require\s*\(?\s*['"]([^'"]+)['"]''', (ROOT / name).read_text(encoding='utf-8')))
resources = ['Parts/Catalog.json', 'Parts/BuildRules.json', 'Endless/Rules.json',
             'Parts/SolidMasks.json', 'Parts/HoverMounts.json']
data = {'golden': golden, 'excludedImports': sorted(imports - set(actual)),
        'allResources': {name: json.loads((ROOT / 'assets' / name).read_text(encoding='utf-8')) for name in resources}}
before = hashes(paths)
fixture = ['tools/migration/check-endless-edit-stock.lua']
checks = execute(fixture, data)
controls = negatives(fixture, [
    (paths[0], 'if not Available(id) then return false end\n        return pick(session,id)', 'return pick(session,id)', 'shortcut 2 matches source'),
    (paths[0], 'if not Available(id) then return false end\n        return assign(session,slot,id)', 'return assign(session,slot,id)', 'active slot matches source'),
    (paths[0], 'panel.Unavailable=function(_,id) return not self:CanSelect(id) end', 'panel.Unavailable=function() return false end', 'actual panel availability matches source'),
    (paths[0], 'cell.root.props.disabled=Inv.Limited(cell.type) and (self.remaining[cell.type] or 0)<=0', 'cell.root.props.disabled=false', 'disabled card follows remaining stock'),
], data)
assert before == hashes(paths), 'Production changed during replay'
report = {'result': 'PASS', 'sourceCommit': golden['commit'], 'sourceHashes': golden['hashes'],
          'sourceCases': len(golden['cases']), 'checks': checks, 'negativeControls': controls,
          'productionHashes': before, 'resources': hashes(['assets/' + name for name in resources]),
          'boundary': 'Complete frozen JS Editor pickPart/assignSlot/selectSlot and EndlessEdit.enter/remainingInventory execute. Real Lua Edit stock guards, BuildSession hotbar/save methods, Inventory, Blueprint.Load/Add/Remove/List, EditHistory.Commit/Undo/Redo, BuildEditor.SelectType, BuildInput.Cancel, InventoryPanel row callbacks and InventoryKeys activate execute. Source Blueprint map and native/UI/resource services adapted. Not Enter/Leave scene lifecycle, actual browser, visual parity, natural combat or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/endless-edit-stock-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'result': 'PASS', 'sourceCases': report['sourceCases'], 'checks': len(checks), 'negativeControls': len(controls), 'evidence': str(out)}))
