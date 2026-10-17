"""Source-executed restored-supply pointer semantics with real Lua release path."""
import json
import re
import subprocess
from g5_offline import ROOT, execute, hashes, negatives

paths=['scripts/app/EndlessSession.lua','scripts/app/TrialSession.lua','scripts/controls/DrivePointer.lua',
       'scripts/controls/MouseDeltaFilter.lua','scripts/endless/Run.lua','scripts/endless/Random.lua','scripts/endless/Data.lua']
before=hashes(paths)
actual={name.removeprefix('scripts/').removesuffix('.lua').replace('/','.') for name in paths}
imports=set()
for name in paths:
    imports.update(re.findall(r'''require\s*\(?\s*['"]([^'"]+)['"]''',(ROOT/name).read_text(encoding='utf-8')))
golden=json.loads(subprocess.check_output(['node','tools/migration/check-endless-rest-input-source.cjs'],encoding='utf-8'))
data={'imports':sorted(imports-actual),'golden':golden,
      'resources':{'Endless/Rules.json':json.loads((ROOT/'assets/Endless/Rules.json').read_text(encoding='utf-8'))}}
fixtures=['tools/migration/check-endless-rest-input.lua']
checks=execute(fixtures,data)
rejected=negatives(fixtures,[
 (paths[0],"if self.run.state=='rest' and #self.run.supplies>0 and (self.session.pointer.captured or self.session.pointer.pending) then",'if false then','source lock state'),
 (paths[0],"self.run.state=='rest' and #self.run.supplies>0",'#self.run.supplies>0','source lock state'),
 (paths[0],"#self.run.supplies>0 and (self.session.pointer.captured or self.session.pointer.pending)","(self.session.pointer.captured or self.session.pointer.pending)",'source lock state'),
 (paths[0],"(self.session.pointer.captured or self.session.pointer.pending)",'self.session.pointer.captured','pending capture canceled before restored supply'),
],data)
assert before==hashes(paths),'Production changed during test'
report={'result':'PASS','sourceCommit':golden['commit'],'sourceHashes':golden['sourceHashes'],'sourceCases':golden['cases'],
        'productionHashes':before,'checks':checks,'negativeControls':rejected,
        'boundary':'Actual complete frozen JS update and Run constructor/chooseSupply and Lua Session.Update/Run restore/ChooseSupply/Trial.Pause/DrivePointer.Release execute. Native audio/camera/input/widget services adapted; no browser, account, visuals, frame time or mobile performance acceptance.'}
out=ROOT/'docs/migration/evidence/endless-rest-input-offline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','sourceCases':len(golden['cases']),'checks':len(checks),'negatives':len(rejected),'evidence':str(out)}))
