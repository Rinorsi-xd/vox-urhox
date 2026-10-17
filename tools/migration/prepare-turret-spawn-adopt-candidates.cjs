const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.tmp/perf-damage-flush-c935-1017/scripts');
const output=path.join(root,'tools/migration/candidates');
function edit(name,changes){
  let text=fs.readFileSync(path.join(source,name),'utf8').replaceAll('\r\n','\n');
  for(const [before,after] of changes){
    assert.equal(text.split(before).length,2,`Unique anchor ${name}: ${before}`);
    text=text.replace(before,after);
  }
  return text;
}
const suffix=fs.readFileSync(path.join(output,'TurretRangeSpawnAdoptApi.lua'),'utf8');
const files={
  'TurretRangeSpawnAdopt.lua':edit('construction/TurretRange.lua', [['return M',suffix+'\nreturn M']]),
  'SpawnSpecCacheTurretAdopt.lua':edit('drive/SpawnSpecCache.lua', [
    ["local Spec=require 'drive.VehicleSpec'","local Spec=require 'drive.VehicleSpec'\nlocal TurretRange=require 'construction.TurretRange'"],
    ['{entries={},disposed=false','{entries={},turretCaches={},disposed=false'],
    ['local spec=Spec.Build(BP.New():Load(snapshot),checkpoint and function() checkpoint() end or nil)',
      'local blueprint=BP.New():Load(snapshot)\n    local spec=Spec.Build(blueprint,checkpoint and function() checkpoint() end or nil)'],
    ['self.entries[key]=spec;self.prepared=self.prepared+1',
      'local turretCache=TurretRange.Capture(blueprint,spec.rotorOf,checkpoint)\n    if self.disposed then return false end\n    self.entries[key]=spec;self.turretCaches[key]=turretCache;self.prepared=self.prepared+1'],
    ['function M:Get(source)','function M:Get(source,actualBlueprint)'],
    ['local template=signature and self.entries[M.VERSION..signature]',
      'local key=signature and M.VERSION..signature\n    local template=key and self.entries[key]'],
    ['self.hits=self.hits+1\n    return Clone(template,{})',
      'self.hits=self.hits+1\n    if actualBlueprint then TurretRange.Adopt(actualBlueprint,template.rotorOf,self.turretCaches[key]) end\n    return Clone(template,{})'],
    ['self.entries={};self.disposed=true','self.entries={};self.turretCaches={};self.disposed=true'],
  ]),
  'CarUnitTurretAdopt.lua':edit('combat/CarUnit.lua',[
    ['self.spawnSpecCache:Get(self.source)','self.spawnSpecCache:Get(self.source,self.bp)'],
  ]),
};
for(const [name,text] of Object.entries(files)){
  const target=path.join(output,name);assert(!fs.existsSync(target),'Preserve existing candidate '+target);
  fs.writeFileSync(target,text);
}
console.log(JSON.stringify({status:'CANDIDATES_CREATED',files:Object.keys(files)}));
