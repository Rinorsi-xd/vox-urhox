'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert.deepEqual(Object.keys(opts).sort(),['frozen','out','variants']);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const fixture=fs.readFileSync(path.join(__dirname,'scope-fx-isolated-observer.lua'));
 const observer=fs.readFileSync(path.join(__dirname,'ads-source-observer.lua'));
 const motionObserver=fs.readFileSync(path.join(__dirname,'weapon-motion-once-observer.lua'));
 const sourceFile=path.resolve(root,opts.out)+'-entry.lua';assert(sourceFile.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(sourceFile));
 fs.writeFileSync(sourceFile,Buffer.concat([main,Buffer.from('\n'),fixture,Buffer.from('\n'),observer,Buffer.from('\n'),motionObserver]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',sourceFile,'--warmup','0','--steps','60']);
 p.scopeFxQa={isolated:true,productionMainSha256:sha(main),types:['mg5','laser5','sniper5','missile5'],boundary:'Existing genuine catalog T5 scope fixture; no save.'};
 p.adsSourceQa={isolated:true,observerSha256:sha(observer),boundary:'Actual EquipmentEmit sourceView identity; shared own particles alive during ADS must have zero accepted draws; the same surviving particles must draw again after release. No geometry replay or production changes.'};
 p.weaponMotionOnceQa={observerSha256:sha(motionObserver),boundary:'Actual per-weapon calls per HandlePostUpdate; functional check only, observer overhead invalidates FPS comparison.'};
 p.g1WebCpu.boundary=p.adsSourceQa.boundary;fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json'),adsSourceQa:p.adsSourceQa}))}catch(e){console.error(e.stack);process.exitCode=1}}
