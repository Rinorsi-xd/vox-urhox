'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv);
 const flushBreakdown=opts['flush-breakdown'];delete opts['flush-breakdown'];
 assert(flushBreakdown===undefined||flushBreakdown==='true','--flush-breakdown true');
 const simulationBreakdown=opts['simulation-breakdown'];delete opts['simulation-breakdown'];
 assert(simulationBreakdown===undefined||(simulationBreakdown==='true'&&flushBreakdown==='true'),'--simulation-breakdown true requires --flush-breakdown true');
 const effectsBreakdown=opts['effects-breakdown'];delete opts['effects-breakdown'];
 assert(effectsBreakdown===undefined||(effectsBreakdown==='true'&&flushBreakdown==='true'&&!simulationBreakdown),'--effects-breakdown true requires flush and excludes simulation probe');
 const turretBreakdown=opts['turret-breakdown'];delete opts['turret-breakdown'];
 assert(turretBreakdown===undefined||(turretBreakdown==='true'&&flushBreakdown==='true'),'--turret-breakdown true requires --flush-breakdown true');
 const turretSourceBreakdown=opts['turret-source-breakdown'];delete opts['turret-source-breakdown'];
 assert(turretSourceBreakdown===undefined||(turretSourceBreakdown==='true'&&flushBreakdown==='true'&&!turretBreakdown),'--turret-source-breakdown true requires --flush-breakdown true and no debug variant');
 assert.deepEqual(Object.keys(opts).sort(),['frozen','out','variants']);assert.equal(opts.variants.length,0);
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8'));
 const main=fs.readFileSync(path.join(frozen.source_directory,'scripts/main.lua'));
 assert.equal(sha(main),frozen.identity.scripts['main.lua']);
 const suffix=fs.readFileSync(path.join(__dirname,'monitor-combat-observer.lua'));
 const flushSuffix=flushBreakdown?fs.readFileSync(path.join(__dirname,'monitor-combat-flush-observer.lua')):Buffer.alloc(0);
 const simulationSuffix=simulationBreakdown?fs.readFileSync(path.join(__dirname,'monitor-combat-simulation-observer.lua')):Buffer.alloc(0);
 const effectsSuffix=effectsBreakdown?fs.readFileSync(path.join(__dirname,'monitor-combat-effects-observer.lua')):Buffer.alloc(0);
 const turretSuffix=turretBreakdown?fs.readFileSync(path.join(__dirname,'monitor-combat-turret-observer.lua')):Buffer.alloc(0);
 const turretSourceSuffix=turretSourceBreakdown?fs.readFileSync(path.join(__dirname,'monitor-combat-turret-source-observer.lua')):Buffer.alloc(0);
 const sourceFile=path.resolve(root,opts.out)+'-entry.lua';assert(!fs.existsSync(sourceFile),'Keep previous entry');
 assert(sourceFile.startsWith(path.join(root,'.tmp')+path.sep));
 const segments=[main,Buffer.from('\n'),suffix];
 if(flushBreakdown)segments.push(Buffer.from('\n'),flushSuffix);
 if(simulationBreakdown)segments.push(Buffer.from('\n'),simulationSuffix);
 if(effectsBreakdown)segments.push(Buffer.from('\n'),effectsSuffix);
 if(turretBreakdown)segments.push(Buffer.from('\n'),turretSuffix);
 if(turretSourceBreakdown)segments.push(Buffer.from('\n'),turretSourceSuffix);
 fs.writeFileSync(sourceFile,Buffer.concat(segments));
 const argumentsForPrepare=['--frozen',opts.frozen,'--out',opts.out,'--probe-file',sourceFile,'--warmup','0','--steps','60'];
 let turretTransform=null;
 let effectsTransform=null;
 if(effectsBreakdown){
  const original=fs.readFileSync(path.join(frozen.source_directory,'scripts/render/CombatEffects.lua'));
  assert.equal(sha(original),frozen.identity.scripts['render/CombatEffects.lua']);
  effectsTransform=require('./monitor-combat-effects-transform.cjs').transform(original);
  const variant=path.resolve(root,opts.out)+'-CombatEffects.lua';assert(!fs.existsSync(variant),'Preserve prior effects derivative');
  fs.writeFileSync(variant,effectsTransform.bytes);argumentsForPrepare.push('--variant','render/CombatEffects.lua='+variant);
 }
 if(turretSourceBreakdown){
  const original=fs.readFileSync(path.join(frozen.source_directory,'scripts/construction/TurretRange.lua'));
  assert.equal(sha(original),frozen.identity.scripts['construction/TurretRange.lua']);
  turretTransform=require('./monitor-combat-turret-source-transform.cjs').transform(original);
  const variant=path.resolve(root,opts.out)+'-TurretRange.lua';assert(!fs.existsSync(variant),'Preserve prior transformed module');
  fs.writeFileSync(variant,turretTransform.bytes);argumentsForPrepare.push('--variant','construction/TurretRange.lua='+variant);
 }
 const prepared=require('./g1-web-cpu-prepare.cjs').prepare(argumentsForPrepare);
 const sources={};for(const name of ['main.lua','diagnostics/PerformanceMonitor.lua','diagnostics/PerformanceBindings.lua','combat/BattleController.lua','drive/Vehicle.lua','combat/CarUnit.lua'])sources[name]=frozen.identity.scripts[name];
 if(flushBreakdown)for(const name of ['construction/Blueprint.lua','drive/VehicleSpec.lua','construction/Rotors.lua','construction/TurretRange.lua'])sources[name]=frozen.identity.scripts[name];
 if(turretSourceBreakdown)sources['construction/TurretRange.lua']=prepared.identity.scripts['construction/TurretRange.lua'];
 if(effectsBreakdown)sources['render/CombatEffects.lua']=prepared.identity.scripts['render/CombatEffects.lua'];
 prepared.monitorCombat={isolated:true,productionMainSha256:sha(main),suffixSha256:sha(suffix),sources,
  monitorEnabled:true,controlledPlacement:true,skipOneTimeOutgameTutorial:true,skipFlag:'VOX_SKIP_TUTORIAL',coarseBindings:3,maxCaptureMs:90000,totalDeadlineMs:300000,
  boundary:'Actual production main plus dedicated QA suffix. All production modules unchanged. Existing QA VOX_SKIP_TUTORIAL skips one-time outgame tutorial without save writes. Full App/render/audio/AI/physics with default enabled monitoring. Eight real cars moved before capture; controlled CPU diagnostic, not tutorial/entry acceptance, natural gameplay or optimization A/B.'};
 prepared.g1WebCpu.boundary=prepared.monitorCombat.boundary;
 if(flushBreakdown)prepared.monitorCombat.flushBreakdown={suffixSha256:sha(flushSuffix),count:8,
  readyEvent:'MONITOR_COMBAT_FLUSH_READY',boundary:'Eight child scopes use existing enabled monitor Wrap after the actual vehicle exists. Additional measurement overhead; attribution only, not an optimization A/B.'};
 if(simulationBreakdown){
  const bindings=[...simulationSuffix.toString('utf8').matchAll(/\{'([^']+)','([^']+)','([^']+)'\}/g)].map(([,module,method,label])=>({module,method,label}));
  assert.equal(bindings.length,29);assert.equal(new Set(bindings.map(x=>x.label)).size,29);
  const sourceHashes={};
  for(const {module}of bindings){const file=module.replaceAll('.','/')+'.lua';sourceHashes[file]=frozen.identity.scripts[file];assert(sourceHashes[file],'Existing frozen module '+file);sources[file]=sourceHashes[file]}
  prepared.monitorCombat.simulationBreakdown={suffixSha256:sha(simulationSuffix),count:bindings.length,bindings,sourceHashes,
   readyEvent:'MONITOR_COMBAT_SIMULATION_READY',debugUpvalues:false,
   boundary:'Twenty-nine existing semantic methods use the real default monitor Wrap. No per-ray/Quad/vertex instrumentation, debug APIs, GC mode changes or gameplay source changes. Child labels aggregate calls per frame, not individual call trees. Measurement overhead excludes matched FPS A/B or device acceptance.'};
 }
 if(effectsBreakdown){
  const bindings=[...effectsSuffix.toString('utf8').matchAll(/\{'([^']+)','([^']+)','([^']+)'\}/g)].map(([,module,method,label])=>({module,method,label}));
  assert.equal(bindings.length,7);const sourceHashes={};
  for(const {module}of bindings){const file=module.replaceAll('.','/')+'.lua';sourceHashes[file]=frozen.identity.scripts[file];assert(sourceHashes[file]);sources[file]=sourceHashes[file]}
  prepared.monitorCombat.effectsBreakdown={suffixSha256:sha(effectsSuffix),count:13,methods:bindings.length,bindings,sourceHashes,
   readyEvent:'MONITOR_COMBAT_EFFECTS_READY',doneEvent:'MONITOR_COMBAT_EFFECTS_DONE',transform:effectsTransform.proof,
   boundary:'Isolated CombatEffects has thirteen reversible whole-section markers with reused scope guards, plus seven exported method boundaries. No per-particle/vertex/Quad instrumentation, forced GC, debug APIs or gameplay changes. Attribution only; not FPS A/B.'};
  prepared.monitorCombat.boundary=prepared.monitorCombat.effectsBreakdown.boundary;
  prepared.g1WebCpu.boundary=prepared.monitorCombat.boundary;
 }
 if(turretBreakdown)prepared.monitorCombat.turretBreakdown={suffixSha256:sha(turretSuffix),
  readyEvent:'MONITOR_TURRET_READY',resultKind:'turret-result',usesDebugUpvalues:true,
  boundary:'Actual For cached lookup and actual Prepare/Evaluate closures; observed only during F9 window. Main-only isolated instrumentation, no production algorithm changes. Shared upvalues and For reference restored after complete-frame export or error. Not an optimization A/B.'};
 if(turretSourceBreakdown){
  prepared.monitorCombat.turretBreakdown={suffixSha256:sha(turretSourceSuffix),readyEvent:'MONITOR_TURRET_READY',resultKind:'turret-result',usesDebugUpvalues:false,
   transform:turretTransform.proof,boundary:'Only derived TurretRange has three reversible entry hooks; algorithms otherwise byte-identical. Main callback observes actual cached presence and Prepare/Evaluate entries, restores global callback after complete-frame export/error. No production workspace modules changed; extra instrumentation, not an optimization A/B.'};
  prepared.monitorCombat.boundary=prepared.monitorCombat.turretBreakdown.boundary;
  prepared.g1WebCpu.boundary=prepared.monitorCombat.boundary;
 }
 fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');
 return prepared;
}
module.exports={prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json'),monitorCombat:p.monitorCombat}))}catch(e){console.error(e.stack);process.exitCode=1}}
