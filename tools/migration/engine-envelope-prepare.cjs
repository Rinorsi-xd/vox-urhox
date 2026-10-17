'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const {one,observer}=require('./sparse-combat-prepare.cjs');
function suffix(duration=45000){
 let s=observer(duration);
 const oldCore=fs.readFileSync(path.join(__dirname,'sparse-combat-core.lua'),'utf8');
 const core=one(oldCore,' local api={names=names}'," local api={names=names}\n function api.EnvelopeState()return enabled,chosen,serial end");
 s=one(s,oldCore,core);
 const addon=fs.readFileSync(path.join(__dirname,'engine-envelope-core.lua'),'utf8');
 s=one(s,`end)().New(${duration})\nlocal presentedFrame=0`,`end)().New(${duration})\nlocal envelope=(function()\n${addon}\nend)().New(sparse)\nlocal presentedFrame=0`);
 s=one(s,' sparse.Start();active=true;lastFrame=0;lastWall=0;Frame()'," envelope.Dump('before');sparse.Start();active=true;lastFrame=0;lastWall=0;Frame()");
 s=one(s," local result=sparse.Stop();result.status='CAPTURED'"," local result=sparse.Stop();result.engineEnvelope=envelope.Stop();result.status='CAPTURED'");
 return s;
}
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv),duration=Number(opts.duration||45000);delete opts.duration;
 assert.deepEqual(Object.keys(opts).sort(),['frozen','out','variants']);assert.equal(opts.variants.length,0);
 const before=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8').replace(/^\uFEFF/,''));
 const main=fs.readFileSync(path.join(before.source_directory,'scripts/main.lua'));assert.equal(sha(main),before.identity.scripts['main.lua']);
 const added=suffix(duration),entry=path.resolve(root,opts.out)+'-entry.lua';assert(entry.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(entry));
 fs.writeFileSync(entry,Buffer.concat([main,Buffer.from('\n'+added)]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',entry,'--warmup','0','--steps','60']);
 const sources={};for(const name of ['main.lua','diagnostics/PerformanceMonitor.lua','combat/BattleController.lua','drive/TrackWorld.lua','render/CombatView.lua','render/CombatEffects.lua'])sources[name]=p.identity.scripts[name];
 p.sparseCombat={isolated:true,monitorEnabled:false,durationMs:duration,sources,productionMainSha256:sha(main),suffixSha256:sha(added),interval:17,
  commitPolicy:'next-Update-after-EndFrame',requireEverySelectedUiRender:true,phaseNames:['dormant-A1','sparse-B','dormant-A2'],
  boundary:'Real public8car combat with sparse semantic scopes and10coarse engine event timestamps. CDP CPU+lightclocktrace are diagnostic overhead, notFPS A/B.'};
 const names=['engine-envelope-core.lua','engine-envelope-prepare.cjs','engine-envelope-run.cjs','engine-envelope-analyze.cjs',
  'sparse-combat-core.lua','sparse-combat-prepare.cjs','sparse-combat-run.cjs','sparse-combat-cpu.cjs','monitor-combat-run.cjs','monitor-combat-observer.lua','monitor-disabled-observer.lua',
  'g1-web-cpu-prepare.cjs','check-engine-envelope.cjs','check-engine-envelope-offline.py'];
 const tools=Object.fromEntries(names.map(n=>[n,sha(fs.readFileSync(path.join(__dirname,n)))]));
 p.engineEnvelope={isolated:true,schema:1,eventCount:10,selectionInterval:17,ringCapacityEvents:512*32,
  nativeDumpPolicy:'before sparse.Start and after sparse.Stop only; raw LogMessage fields/control/overflow retained',tools};
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');
 return p;
}
module.exports={suffix,prepare};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(p.source_directory,'identity.json'),manifest:path.basename(p.manifest_path),sparseCombat:p.sparseCombat,engineEnvelope:p.engineEnvelope},null,2));}catch(e){console.error(e.stack);process.exitCode=1;}}
