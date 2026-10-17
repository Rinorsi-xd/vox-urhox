"""Execute complete frozen H5 and production Lua modules; no renderer benchmark."""
import json,re,subprocess
from g5_offline import ROOT,execute,hashes,negatives
paths=['scripts/render/CombatEffects.lua','scripts/render/WeaponEffects.lua','scripts/app/TrialSession.lua']
before=hashes(paths)
actual={'render.CombatEffects','render.WeaponEffects','core.Math3','render.NodeVisibility'}
imports=set()
for p in paths: imports.update(re.findall(r'''require\s*\(?\s*['"]([^'"]+)['"]''',(ROOT/p).read_text(encoding='utf-8')))
golden=json.loads(subprocess.check_output(['node','tools/migration/check-first-person-fx-source.cjs'],encoding='utf-8'))
data={'imports':sorted(imports-actual),'golden':golden}
fixtures=['tools/migration/check-first-person-fx.lua']
checks=execute(fixtures,data)
rejected=negatives(fixtures,[
 (paths[0],'then if not own then self:Shot(e) end','then self:Shot(e)','source visual event count'),
 (paths[0],"local near=p.fx=='missile' and 6 or 12","local near=0",'source projectile count'),
 (paths[0],'copy.dist=p.dist-near','copy.dist=p.dist','source projectile distance'),
 (paths[0],'math.min(10,V.Length(V.Sub(e.to,e.from))*.5)','0','source beam start'),
 (paths[1],'b.mesh.enabled=self.visible and b.count>0','b.mesh.enabled=b.count>0','scope hides sibling batch'),
 (paths[2],'local pivot=self:ScopePivot()','local pivot=self.firstPerson','current scope first tick'),
 (paths[0],'projectiles=self:Projectiles(projectiles)','-- disabled near filtering','actual Update filters near bolt'),
 (paths[2],'if self.view.view.weaponEffects then self.view.view.weaponEffects:SetVisible(not self.firstPerson and root.enabled) end','-- disabled sibling visibility','actual PostUpdate scope hides vehicle'),
],data)
assert before==hashes(paths),'Production changed during validation'
out=ROOT/'docs/migration/evidence/first-person-fx-offline.json'
out.write_text(json.dumps({'result':'PASS','sourceCommit':golden['commit'],'sourceHashes':golden['sourceHashes'],
 'productionHashes':before,'sourceCases':len(golden['cases']),'checks':checks,'negativeControls':rejected,
 'boundary':'Complete frozen H5 TestDrive._effects and production Lua CombatEffects/WeaponEffects/TrialSession methods execute. Render/audio/input services adapted. No Web screenshots, FPS, occlusion, phone or visual acceptance.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','sourceCases':len(golden['cases']),'checks':len(checks),'negatives':len(rejected),'evidence':str(out)}))
