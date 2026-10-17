'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);assert.deepEqual(Object.keys(opts).sort(),opts.compact===undefined?['frozen','out','variants']:['compact','frozen','out','variants']);assert.equal(opts.variants.length,0);
 if(opts.compact!==undefined)assert(['0','1'].includes(opts.compact));
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));
 assert.equal(sha(main),frozen.identity.scripts['main.lua']);const observer=fs.readFileSync(path.join(__dirname,'scope-fx-isolated-observer.lua'));
 const suffix=Buffer.concat([Buffer.from(opts.compact===undefined?'':"require('controls.TouchMode').compactOverride="+(opts.compact==='1'?'true':'false')+'\n'),observer]);
 const sourceFile=path.resolve(root,opts.out)+'-entry.lua';assert(sourceFile.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(sourceFile));
 fs.writeFileSync(sourceFile,Buffer.concat([main,Buffer.from('\n'),suffix]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',sourceFile,'--warmup','0','--steps','60']);
 p.scopeFxQa={isolated:true,productionMainSha256:sha(main),suffixSha256:sha(suffix),types:['mg5','laser5','sniper5','missile5'],
  boundary:'Actual production main plus QA suffix. Synthetic connected chassis uses genuine T5 catalog parts. QA replaces in-memory blueprint, enters ordinary TrialSession and may reposition one actual parked target before input testing. All production modules unchanged; no save action. F7/F6 are explicit QA controls, F9 read-only observation. Not public entry/natural gameplay, performance or phone acceptance.'};
 if(opts.compact!==undefined){p.scopeFxQa.compact=opts.compact==='1';p.scopeFxQa.boundary+=' Controlled startup compactOverride in QA suffix, no compact command-line argument; not an engine argument acceptance.'}
 p.g1WebCpu.boundary=p.scopeFxQa.boundary;fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare};if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json'),scopeFxQa:p.scopeFxQa}))}catch(e){console.error(e.stack);process.exitCode=1}}
