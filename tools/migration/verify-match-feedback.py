"""Execute frozen MatchHud methods and production Lua without a GPU."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source = json.loads(subprocess.check_output(['node', '--experimental-vm-modules',
    'tools/migration/match-feedback-source.mjs'], text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
module = lua.execute("return require('ui.MatchFeedback')")[0]
checks = []
def check(ok, label):
    assert ok, label
    checks.append(label)
for i, case in enumerate(source['cases']):
    b = lua.table_from({'mode': case['mode'], 'intro': case['intro'],
        'rules': lua.table_from({'state': case['state'], 'cfg': lua.table_from({'prep': 10}), 't': case['t'], 'sudden': True}),
        'player': lua.table_from({'alive': case['alive']})})
    module.Update(b, 2)
    check(b.prepCount == case['count'], f'source actual countdown {i}')
    check(bool(module.RepairDisabled(b)) == case['disabled'], f'source actual repair notice {i}')
b = lua.table_from({'rules': lua.table_from({'state': 'prep', 'cfg': lua.table_from({'prep': 10}), 't': 9})})
module.Update(b, 2, True)
check(b.prepCount == 0, 'actual session intro suppresses prep count without battle.intro')
module.Update(b, 2.1, False)
check(b.prepCount == 1, 'finished session intro restores prep count')
b = lua.table_from({'rules': lua.table_from({'state': 'live'}), 'player': lua.table()})
for i, case in enumerate(source['hurt']):
    before = b.hurtAt
    module.Consume(b, lua.table_from([lua.table_from({'type': 'unitDamaged', 'unit': b.player, 'amount': 1})]), case['time'])
    check((b.hurtAt != before) == case['accepted'], f'source actual hurt throttle {i}')
check(module.HurtAlpha(b, 1.7) == 1, 'hurt visible before frame')
module.Update(b, 1.72)
check(module.HurtAlpha(b, 1.72) == 1, 'hurt survives first animation frame')
module.Update(b, 1.74)
check(module.HurtAlpha(b, 1.74) == 1, 'second frame starts fade at full opacity')
check(0 < module.HurtAlpha(b, 1.99) < 1, 'CSS half-second fade in progress')
check(module.HurtAlpha(b, 2.24) == 0, 'CSS half-second fade finished')
for amount in [0, -1]:
    module.Consume(b, lua.table_from([lua.table_from({'type': 'unitDamaged', 'unit': b.player, 'amount': amount})]), 3)
    check(b.hurtAt == 1.7, 'nonpositive damage does not flash')
for event in [{'type': 'unitHealed', 'unit': b.player, 'amount': 10}, {'type': 'unitDamaged', 'unit': lua.table(), 'amount': 10}]:
    module.Consume(b, lua.table_from([lua.table_from(event)]), 3)
    check(b.hurtAt == 1.7, 'other events do not flash player')
lua.execute("Time={GetSystemTime=function() return 4000 end}; package.loaded['urhox-libs/UI']={}; package.loaded['core.Coord']={}; package.loaded['ui.UnitMarkState']={}")
overlay = lua.execute("return dofile('scripts/ui/DriveOverlay.lua')")
owner = lua.table_from({'session': lua.table_from({'battle': b})})
overlay.Consume(owner, lua.table_from([lua.table_from({'type': 'unitDamaged', 'unit': b.player, 'amount': 5})]))
check(b.hurtAt == 4, 'actual DriveOverlay event consumer forwards battle damage')
paths = ['scripts/ui/MatchFeedback.lua', 'scripts/ui/MatchHud.lua', 'scripts/ui/DriveOverlay.lua']
for name in paths:
    lua.execute('assert(loadfile(...))', name)
report = {'result': 'PASS', 'checks': len(checks), 'source': source['source'],
    'productionHashes': {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in paths},
    'boundary': 'Frozen JS MatchHud.update/hurt and production Lua state/event integration; no actual rendered or target-device acceptance. Red edge approximates CSS inset shadow with shared-frame gradients.'}
out = root/'docs/migration/evidence/match-feedback-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
