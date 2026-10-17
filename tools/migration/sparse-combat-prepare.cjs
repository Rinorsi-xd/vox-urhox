'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function one(text,old,value){assert.equal(text.split(old).length,2,'Unique source anchor: '+old.slice(0,80));return text.replace(old,value)}
function observer(duration=45000){
 assert(Number.isInteger(duration)&&duration>=30000&&duration<=90000);
 let s=fs.readFileSync(path.join(__dirname,'monitor-combat-observer.lua'),'utf8');
 const first=s.indexOf('local function Frame()'),last=s.indexOf('local function Finite(');assert(first>0&&last>first);
 const core=fs.readFileSync(path.join(__dirname,'sparse-combat-core.lua'),'utf8');
 s=s.slice(0,first)+`local sparse=(function()\n${core}\nend)().New(${duration})\n`+`local presentedFrame=0\nlocal function Frame()\n local f=GetTime().frameNumber\n assert(index==committedIndex,'Uncommitted actual frame')\n index=index+1;frameIds[index]=f;sparse.Frame(f)\nend\nlocal function Commit()\n if not active then return end\n assert(index>committedIndex and presentedFrame==frameIds[index],'Previous actual frame must reach EndFrame before next Update commits it')\n sparse.Commit(app.trial.fixedSteps);committedIndex=index\n local stats=app.trial.world.stats\n shots[index]=stats.shots;hits[index]=stats.hits;damage[index]=stats.damage;kills[index]=stats.kills\n local count=0;for _,e in ipairs(app.trial.battle.entries)do count=count+e.unit.bp:Size()end;parts[index]=count\nend\n`+s.slice(last);
 s=one(s,"assert(performance.enabled,'Keep default production monitor enabled')","assert(not performance.enabled,'Sparse attribution requires Monitor disabled before startup')");
 s=one(s,'Aim(target);captureBefore=Current();active=true;lastFrame=0;lastWall=0',`Aim(target);captureBefore=Current()
 sparse.Wrap(require('combat.BattleController'),'BeforeStep',1)
 sparse.Wrap(require('drive.TrackWorld'),'Step',2)
 sparse.Wrap(require('combat.BattleController'),'AfterStep',3)
 sparse.Wrap(require('render.CombatView'),'Update',4)
 sparse.Wrap(require('render.CombatEffects'),'Update',5)
 sparse.Wrap(app.trial.hud,'Update',6)
 sparse.Wrap(UI,'Render',7)
 local owner={Update=updateForSparse};sparse.Wrap(owner,'Update',8);updateForSparse=owner.Update
 sparse.Start();active=true;lastFrame=0;lastWall=0;Frame()`);
 // The local update owner must exist before StartCapture closes over it.
 s=one(s,'local function StartCapture()','local updateForSparse=HandleUpdate\nlocal function StartCapture()');
 const a=s.indexOf(" Chunk('result',{status='CAPTURED'"),b=s.indexOf('\nend\nlocal function Snapshot()',a);assert(a>0&&b>a);
 s=s.slice(0,a)+` local result=sparse.Stop();result.status='CAPTURED';result.setup=setup;result.before=captureBefore;result.after=captureAfter
 result.parts=parts;result.shots=shots;result.hits=hits;result.damage=damage;result.kills=kills
 Chunk('result',result)`+s.slice(b);
 s=one(s,'local update=HandleUpdate\nfunction HandleUpdate(...)','function HandleUpdate(...)');
 s=one(s,' if active then Frame()end',` if active then
  Commit()
  if stopRequested then stopRequested=false;EndCapture()else Frame()end
 end`);
 s=one(s,' update(...)',' updateForSparse(...)');
 s=one(s,' presented(...);Commit()\n if stopRequested then stopRequested=false;EndCapture()end',` presented(...)
 if active then
  assert(index>committedIndex and frameIds[index]==GetTime().frameNumber,'EndFrame belongs to actual current sparse frame')
  presentedFrame=frameIds[index]
 end`);
 return fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua'),'utf8')+'\n'+s;
}
function prepare(argv){
 const opts=require('./g1-web-cpu-prepare.cjs').options(argv),duration=Number(opts.duration||45000);delete opts.duration;
 assert.deepEqual(Object.keys(opts).sort(),['frozen','out','variants']);assert.equal(opts.variants.length,0);
 const before=JSON.parse(fs.readFileSync(path.resolve(root,opts.frozen),'utf8').replace(/^\uFEFF/,''));
 const main=fs.readFileSync(path.join(before.source_directory,'scripts/main.lua'));assert.equal(sha(main),before.identity.scripts['main.lua']);
 const suffix=observer(duration),entry=path.resolve(root,opts.out)+'-entry.lua';assert(entry.startsWith(path.join(root,'.tmp')+path.sep));assert(!fs.existsSync(entry));
 fs.writeFileSync(entry,Buffer.concat([main,Buffer.from('\n'+suffix)]));
 const p=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',opts.frozen,'--out',opts.out,'--probe-file',entry,'--warmup','0','--steps','60']);
 const sources={};for(const name of ['main.lua','diagnostics/PerformanceMonitor.lua','combat/BattleController.lua','drive/TrackWorld.lua','render/CombatView.lua','render/CombatEffects.lua'])sources[name]=p.identity.scripts[name];
 p.sparseCombat={isolated:true,monitorEnabled:false,durationMs:duration,sources,productionMainSha256:sha(main),suffixSha256:sha(suffix),interval:17,commitPolicy:'next-Update-after-EndFrame',requireEverySelectedUiRender:true,
  phaseNames:['dormant-A1','sparse-B','dormant-A2'],boundary:'Actual public eight-car match, default Monitor disabled before Start. Sparse semantic owners plus CPU sampling only. No trace, per-ray wrappers, FPS benefit A/B or mobile acceptance.'};
 fs.writeFileSync(path.join(p.source_directory,'identity.json'),JSON.stringify(p,null,2)+'\n');return p;
}
module.exports={prepare,observer,one};
if(require.main===module){try{const p=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'READY_NOT_RUN',identity:path.join(p.source_directory,'identity.json'),sparseCombat:p.sparseCombat}))}catch(e){console.error(e.stack);process.exitCode=1}}
