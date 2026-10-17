'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),Module=require('node:module');
const {one}=require('./sparse-combat-prepare.cjs');
function analyze(r){
 assert.equal(r.status,'CAPTURED');assert.equal(r.before.monitorEnabled,false);assert.equal(r.after.monitorEnabled,false);
 assert.equal(r.setup.before.monitorEnabled,false);assert.equal(r.setup.after.monitorEnabled,false);
 const original=require('./monitor-combat-run.cjs');
 const setup=structuredClone(r.setup);setup.before.monitorEnabled=true;setup.after.monitorEnabled=true;original.verifySetup(setup);
 assert.deepEqual(r.before.roster.map(original.signature),r.after.roster.map(original.signature));
 const n=r.frameIds.length;assert(n>=3&&n<=4096);assert.equal(r.rows.length,r.sampleCount*24);assert(r.sampleCount>0);
 for(const name of ['wallMs','selected','phases','parts','shots','hits','damage','kills','fixedSteps'])assert.equal(r[name].length,n,name);
 for(let i=1;i<n;i++){assert.equal(r.frameIds[i],r.frameIds[i-1]+1);assert(r.phases[i]>=r.phases[i-1]);}
 assert.deepEqual([...new Set(r.phases)],[1,2,3],'All dormant/sparse/dormant phases');
 let selected=0;for(let i=0;i<n;i++){if(r.selected[i]){assert.equal(r.phases[i],2);assert.equal((i+1)%17,0);assert.equal(r.selected[i],++selected);}}
 assert.equal(selected,r.sampleCount);assert(r.rows.every(v=>Number.isInteger(v)&&v>=0));
 for(let i=0;i<r.sampleCount;i++)assert(r.rows[i*24+19]>0,'Every selected complete frame must cover actual UI.Render; zero calls is a coverage failure, never free UI');
 assert(r.after.world.shots>r.before.world.shots&&r.after.world.hits>r.before.world.hits,'Real combat shots/hits');
 assert(r.after.playerDamage>r.before.playerDamage,'Real player damage');
 assert(r.after.roster.some((u,i)=>u.parts<r.before.roster[i].parts||u.structure<r.before.roster[i].structure)||Math.min(...r.parts)<r.before.roster.reduce((s,u)=>s+u.parts,0),'Real structural damage');
 const phases=[1,2,3].map(p=>{const times=r.phases.flatMap((phase,i)=>phase===p&&i>0&&i<n-1?[r.wallMs[i+1]]:[]).sort((a,b)=>a-b);assert(times.length>0);return {phase:r.phaseNames[p-1],frames:times.length,meanWallMs:times.reduce((a,b)=>a+b,0)/times.length,p95WallMs:times[Math.ceil(times.length*.95)-1],over80:times.filter(x=>x>80).length};});
 const selectedSteps=r.selected.reduce((sum,selection,i)=>sum+(selection&&i>0?r.fixedSteps[i]-r.fixedSteps[i-1]:0),0);
 const scopes=r.names.map((name,j)=>{let totalMs=0,calls=0,maxCallMs=0;for(let i=0;i<r.sampleCount;i++){const k=i*24+j*3;totalMs+=r.rows[k];calls+=r.rows[k+1];maxCallMs=Math.max(maxCallMs,r.rows[k+2]);}return {name,totalMs,calls,maxCallMs,meanMsPerSelectedFrame:totalMs/r.sampleCount,meanMsPerSelectedFixedStep:selectedSteps?totalMs/selectedSteps:null};});
 return {status:'PASS_ATTRIBUTION_ONLY',sampleCount:r.sampleCount,markerCount:r.markerCount,phases,scopes,boundary:r.boundary+' Combat naturally evolves across phases; no causal overhead or optimization benefit percentage.'};
}
function runnerSource(){
 let source=fs.readFileSync(path.join(__dirname,'monitor-combat-run.cjs'),'utf8');
 const analysisStart=source.indexOf('function analyze(r){'),runStart=source.indexOf('async function run(');
 assert(analysisStart>0&&runStart>analysisStart,'Unique legacy analysis/selftest section');
 source=source.slice(0,analysisStart)+"function analyze(r){return global.__voxSparseAnalyze(r)}\nfunction selfTest(){throw Error('Use check-sparse-combat.cjs')}\n"+source.slice(runStart);
 source=one(source,"assert.equal(s.before.monitorEnabled,true);assert.equal(s.after.monitorEnabled,true);","assert.equal(s.before.monitorEnabled,false);assert.equal(s.after.monitorEnabled,false);");
 source=one(source,'assert.equal(state.monitorEnabled,true);','assert.equal(state.monitorEnabled,false);');
 source=one(source,"assert(identity.monitorCombat?.isolated&&identity.monitorCombat.monitorEnabled&&identity.monitorCombat.coarseBindings===3);","assert(identity.sparseCombat?.isolated&&identity.sparseCombat.monitorEnabled===false);assert.equal(duration,identity.sparseCombat.durationMs);");
 source=one(source,'Object.keys(identity.monitorCombat.sources)','Object.keys(identity.sparseCombat.sources)');
 source=one(source,"if(diagnostic)await bounded(diagnostic.stop('capture-complete'),'CDP diagnostic stop');","if(diagnostic)try{await bounded(diagnostic.stop('capture-complete'),'CDP diagnostic stop')}catch(error){report.cdpFailure=error.stack;report.diagnosticStatus='FAILED';persist()}");
 source=one(source,"page=await bounded(browser.newPage({viewport:{width:1600,height:900}}),'page');","page=await bounded(browser.newPage({viewport:{width:1600,height:900}}),'page');await diagnostic.install(page);");
 source=one(source,'report.analysis=analyze(result);',"report.analysis=global.__voxSparseAnalyze(result);try{const sync=JSON.parse(fs.readFileSync(path.join(out,'sparse-sync.json')));assert.equal(sync.rows.length,result.markerCount,'All Lua semantic markers arrived synchronously')}catch(error){report.syncFailure=error.stack;report.diagnosticStatus='FAILED';report.cdpFailure??=error.stack}");
 source=one(source,"report.status='PASS';report.checks=[","report.gameplayStatus='PASS';report.status=report.diagnosticStatus==='FAILED'?'FAIL':'PASS';report.checks=[");
 source=one(source,"'Default monitoring enabled'","'Production monitoring disabled before Start'");
 source=one(source,"'Three coarse monitor scopes'","'Sparse semantic scopes every 17 frames in middle third'");
 assert(!/monitorEnabled\s*,\s*true|monitorEnabled\s*:\s*true|monitorEnabled\s*&&/.test(source),'No inherited monitor-enabled gate survives in sparse runner');
 return source;
}
function buildRunner(){
 const source=runnerSource();
 const m=new Module(path.join(__dirname,'sparse-combat-runtime.cjs'),module);m.filename=path.join(__dirname,'sparse-combat-runtime.cjs');m.paths=module.paths;m._compile(source,m.filename);return m.exports.run;
}
async function run(base,out,duration=45000){
 assert(!global.__voxSparseAnalyze);global.__voxSparseAnalyze=analyze;
 try{return await buildRunner()(base,out,duration,require('./sparse-combat-cpu.cjs').create(out));}
 finally{delete global.__voxSparseAnalyze;}
}
module.exports={run,analyze,buildRunner,runnerSource};
if(require.main===module)run(process.argv[2],path.resolve(process.argv[3]),Number(process.argv[4]||45000)).catch(e=>{console.error(e.stack);process.exitCode=1});
