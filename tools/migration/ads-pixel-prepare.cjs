'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);
 assert.deepEqual(Object.keys(opts).sort(),['frozen','out','variants']);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));
 assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const fixture=fs.readFileSync(path.join(__dirname,'scope-fx-isolated-observer.lua'));
 const batch=fs.readFileSync(path.join(__dirname,'ads-pixel-batch.lua'));
 const observer=fs.readFileSync(path.join(__dirname,'ads-pixel-observer.lua'));
 const suffix=Buffer.concat([fixture,Buffer.from('\ndo\nlocal AdsPixelBatch=(function()\n'),batch,Buffer.from('\nend)()\n'),observer,Buffer.from('\nend\n')]);
 const sourceFile=path.resolve(root,opts.out)+'-entry.lua';
 assert(sourceFile.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(sourceFile));
 fs.writeFileSync(sourceFile,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',sourceFile,'--warmup','0','--steps','60']);
 p.scopeFxQa={isolated:true,productionMainSha256:sha(main),suffixSha256:sha(suffix),types:['mg5','laser5','sniper5','missile5'],
  boundary:'Production main plus isolated genuine catalog T5 connected fixture; no save. Existing F7/F6/F9 controls. Not natural/public gameplay or performance acceptance.'};
 p.adsPixelQa={isolated:true,batchSha256:sha(batch),observerSha256:sha(observer),
  boundary:'Replay only recorded accepted quads, preserving camera, FX age, clock and submission attributes. Frozen 0 baseline; 8 only own VehicleView WeaponView.Update EquipmentEmit; 9 all EquipmentEmit; 7 all Streak independent category. A1/A2 center pixels and invariant digest must match. No effects Update(0), no production edit or save.'};
 p.g1WebCpu.boundary=p.adsPixelQa.boundary;
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json'),adsPixelQa:p.adsPixelQa}))}catch(e){console.error(e.stack);process.exitCode=1}}
