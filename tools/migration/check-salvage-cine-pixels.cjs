const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
(async()=>{
 const report={manifest:path.basename(prepared.manifest_path),checks:[]};
 for(const name of ['pc','phone-landscape','tablet']){
  const prefix='salvage-cine-web-'+name,run=JSON.parse(fs.readFileSync(path.join(out,prefix+'.json')));
  assert.equal(run.result,'PASS');assert.equal(run.manifest,report.manifest);
  for(const stage of ['spawn','running','extract-hook','extract-climb','death','returned']){
   const file=prefix+'-'+stage+'.png',meta=await sharp(path.join(out,file)).metadata();
   assert.equal(meta.width,run.viewport.width*(run.viewport.dpr||1));assert.equal(meta.height,run.viewport.height*(run.viewport.dpr||1));
   const rect={left:Math.floor(meta.width*.2),top:Math.floor(meta.height*.2),width:Math.floor(meta.width*.6),height:Math.floor(meta.height*.6)};
   const crop=await sharp(path.join(out,file)).extract(rect).png().toBuffer();
   const stats=await sharp(crop).stats(),deviation=stats.channels.slice(0,3).map(c=>c.stdev);
   assert.ok(Math.max(...deviation)>3&&stats.entropy>.25,file+' has a blank/flat central scene');
   report.checks.push({file,width:meta.width,height:meta.height,rect,deviation,entropy:stats.entropy});
  }
 }
 report.result='PASS';fs.writeFileSync(path.join(out,'salvage-cine-pixels.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,manifest:report.manifest,images:report.checks.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});
