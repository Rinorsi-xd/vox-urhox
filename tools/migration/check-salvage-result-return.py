"""Frozen result order and real Lua settlement/lifecycle; no engine execution."""
import hashlib
import json
from pathlib import Path
import subprocess
from g5_offline import execute, hashes, negatives, ROOT, LuaRuntime

source = json.loads(subprocess.check_output(['node', 'tools/migration/check-salvage-result-return-source.cjs'], cwd=ROOT, text=True, encoding='utf-8'))
paths = ['scripts/salvage/Run.lua', 'scripts/salvage/ResultReturn.lua', 'scripts/app/SalvageLobby.lua',
         'scripts/salvage/RunRules.lua', 'scripts/salvage/Loot.lua', 'scripts/ui/SalvageRunHud.lua', 'scripts/app/HangarApp.lua',
         'scripts/app/TrialSession.lua']
paths.append('scripts/controls/DriveAim.lua')
before = hashes(paths)
qa_paths = ['scripts/salvage/ResultReturn.lua.meta', 'tools/migration/probe-outgame-web.lua',
            'tools/migration/check-salvage-natural-web.cjs', 'tools/migration/salvage-return-acceptance.cjs',
            'tools/migration/check-salvage-return-acceptance.cjs', 'tools/migration/check-salvage-settlement.lua',
            'tools/migration/check-salvage-cine.lua', 'tools/migration/check-salvage-result-return.lua',
            'tools/migration/check-salvage-result-return-source.cjs', 'tools/migration/check-salvage-result-return.py']
compiler = LuaRuntime(unpack_returned_tuples=True)
syntax_paths = [p for p in paths + qa_paths if p.endswith('.lua')]
for name in syntax_paths:
    compiler.execute("assert(load(...))", (ROOT / name).read_text(encoding='utf-8'))
data = {'fixtures': source, 'resources': {p: json.loads((ROOT / 'assets' / p).read_text(encoding='utf-8'))
        for p in ['UI/Outgame.json', 'UI/SalvageRules.json', 'Salvage/RunData.json']}}
trial_source = (ROOT / 'scripts/app/TrialSession.lua').read_text(encoding='utf-8')
data['trialDisposeSource'] = trial_source[trial_source.index('function M:Dispose(checkpoint)'):trial_source.rindex('\nreturn M')]+'\nreturn M.Dispose'
aim_source = (ROOT / 'scripts/controls/DriveAim.lua').read_text(encoding='utf-8')
data['driveAimClearSource'] = 'local M={}\n'+aim_source[aim_source.index('function M.Clear(s)'):aim_source.index('function M.Resolve')]+ '\nreturn M'
fixture = ['tools/migration/check-salvage-result-return.lua']
checks = execute(fixture, data)
rejected = negatives(fixture, [
    ('scripts/salvage/Run.lua', 'self.returnDelay=.25', 'self.returnDelay=0', 'source 250ms delay retained'),
    ('scripts/salvage/Run.lua', 'ResultReturn.Queue(self,abandoned and .2 or 0)', 'ResultReturn.Queue(self,0)', 'abandon 200ms result delay retained'),
    ('scripts/salvage/ResultReturn.lua', "app.mode~='hangar' or app.trial or not app.scene", 'not app.scene', 'live battle cannot show hall result'),
    ('scripts/salvage/ResultReturn.lua', 'result=Copy(run.result)', 'result=run.result', 'detached result data'),
    ('scripts/ui/SalvageRunHud.lua', 'if run.committed then if onDismiss then onDismiss() end else run.shown=false end', 'if onDismiss then onDismiss() end', 'unsaved result close remains pending'),
    ('scripts/salvage/Run.lua', 'if self.begun and not self.result and not self.rules.finished then', 'if false then', 'direct reload dispose settles begun raid'),
    ('scripts/salvage/Run.lua', 'return key~=KEY_ESCAPE and key~=KEY_T\n    end\n    if self.rules.finished', 'return true\n    end\n    if self.rules.finished', 'frozen blocking key contract'),
], data)
app = (ROOT / 'scripts/app/HangarApp.lua').read_text(encoding='utf-8')
hook = "SalvageResultReturn.Update(self,Hud.GetState(),dt,DeferredModules['ui.SalvageRunHud'].Result)"
assert app.count(hook) == 1
assert app.index(hook) > app.index("if self.loadingFlow and self.loadingFlow.active then", app.index('function App:Update'))
assert before == hashes(paths)
report = {'result': 'PASS', 'sourceCommit': source['commit'], 'sourceHashes': source['sourceHashes'],
          'productionHashes': before, 'qaHashes': hashes(qa_paths), 'syntaxPaths': syntax_paths, 'sourceCases': source['cases'], 'sourceControls': source.get('controls'), 'checks': checks, 'negativeControls': rejected,
          'boundary': 'Actual frozen _extracted/_fail/_finish/dispose and Stash economic methods; PART_LIST import uses migration Outgame catalogue, drive exit, DOM, clocks and save edges adapted. Actual Lua Finish/Return/Run.Dispose and enclosing TrialSession.Dispose body, ResultReturn and Lobby.CommitRun, actual HUD callbacks with widget services adapted. Hall loading/app hook source order checked; no full HangarApp runtime, Native store rerun, public Web return, account, cloud ACK, visuals or performance acceptance.'}
out = ROOT / 'docs/migration/evidence/salvage-result-return-offline.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'result':'PASS', 'checks':len(checks), 'negativeControls':len(rejected), 'evidence':str(out)}))
