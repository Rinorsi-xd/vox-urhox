'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const evidence=path.resolve(root,process.argv[2]||'docs/migration/evidence/boss-missile-web-4a3a-1017-a');
const output=path.resolve(root,process.argv[3]||'docs/migration/evidence/boss-missile-web-4a3a-1017-a-independent.json');
assert(!fs.existsSync(output),'Preserve existing independent result');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const report=JSON.parse(fs.readFileSync(path.join(evidence,'report.json'),'utf8'));
assert.equal(report.status,'PASS');assert.equal(report.shutdown,'CLOSED');
assert.equal(report.errors.length,0);assert.equal(report.httpErrors.length,0);assert.equal(report.identity.qa,false);
const grouped=new Map();let chunks=0;
for(const line of fs.readFileSync(path.join(evidence,'runtime.log'),'utf8').split(/\r?\n/)){
 const prefix='BOSS_MISSILE_CHUNK ',at=line.indexOf(prefix);if(at<0)continue;
 const chunk=JSON.parse(line.slice(at+prefix.length));chunks++;
 let item=grouped.get(chunk.kind);
 if(!item){item={count:chunk.count,bytes:chunk.bytes,checksum:chunk.checksum,parts:new Map()};grouped.set(chunk.kind,item)}
 assert.equal(chunk.count,item.count);assert.equal(chunk.bytes,item.bytes);assert.equal(chunk.checksum,item.checksum);
 assert(!item.parts.has(chunk.index),'Duplicate runtime chunk');item.parts.set(chunk.index,chunk.data);
}
const states=[];
for(const [kind,item]of grouped){
 assert.equal(item.parts.size,item.count,'Complete runtime chunks');let text='';
 for(let i=1;i<=item.count;i++){assert(item.parts.has(i));text+=item.parts.get(i)}
 const bytes=Buffer.from(text);assert.equal(bytes.length,item.bytes);let hash=2166136261;
 for(const byte of bytes)hash=Math.imul(hash^byte,16777619)>>>0;
 assert.equal(hash,item.checksum);const state=JSON.parse(text);assert.equal(kind,'state-'+state.sequence);
 for(const key of ['widgets','cases','actions'])if(!Array.isArray(state[key]))state[key]=[];
 states.push(state);
}
for(let i=0;i<states.length;i++){assert.equal(states[i].sequence,i+1);if(i)assert(states[i].frame>=states[i-1].frame)}
function actual(state){const raw=states.find(s=>s.sequence===state.sequence);assert(raw);assert.deepEqual(raw,state);return raw}
const impact=actual(report.impacts),returned=actual(report.returned);actual(report.lastState);
for(const shot of report.screenshots)actual(shot.state);
assert(impact.sameMission&&impact.trial&&!impact.loading&&impact.captured);
assert.equal(impact.story.id,'s5');assert(impact.story.begun);assert.equal(impact.setup.bossParts,2227);
assert.equal(impact.setup.index,2);assert.equal(impact.setup.flow,'fight');assert(impact.setup.bossAlive);
assert(impact.setup.wrappersRestored&&impact.setup.authoredOutsideAbsent);assert.equal(impact.setup.time,impact.setup.afterTime);
assert.equal(impact.setup.finalMissiles,0);assert.equal(impact.actions.length,1);
assert.deepEqual([impact.actions[0].kind,impact.actions[0].map,impact.actions[0].accepted],['EnterTrial','story5',true]);
const cases=impact.cases;assert.equal(cases.length,3);
assert.deepEqual(cases.map(c=>c.name),['player-impact','stronger-impact','distant-miss']);
for(let i=0;i<cases.length;i++){
 const c=cases[i];assert.equal(c.frame,cases[0].frame);assert(c.before.alive&&c.after.alive);
 assert.deepEqual([c.missilesBefore,c.enqueued,c.remaining,c.fxCalls],[0,1,0,1]);assert(c.attackerCleared);
 assert.equal(c.hitDelta,i<2?1:0);assert.equal(c.hitsAfter-c.hitsBefore,c.hitDelta);
 assert.equal(c.explodeCalls,i<2?1:0);assert.equal(c.flushCalls,i<2?1:0);
 assert.equal(c.traumaBefore,[0,.8,0][i]);assert.equal(c.traumaAfter,[.35,.8,0][i]);
 if(i<2){
  assert(c.dealt>0);assert(Math.abs(c.before.structure-c.after.structure-c.dealt)<1e-10);
  assert.deepEqual([c.explosion.radius,c.explosion.damage,c.explosion.attackerIsBoss],[7.5,5,true]);
  const los=c.rays.filter(ray=>ray.direction[1]===-1&&ray.length===1);
  const roof=c.rays.filter(ray=>ray.direction[1]===1&&ray.length===90);
  assert.equal(los.length,1);assert.equal(los[0].hit,false);
  assert.equal(roof.length,1);assert.equal(roof[0].hit,false);assert.equal(roof[0].excludesPlayer,true);
 }else {assert.equal(c.before.structure,c.after.structure);assert.deepEqual(Object.keys(c.rays),[])}
 if(i){assert.equal(c.hitsBefore,cases[i-1].hitsAfter);assert.deepEqual(c.before,cases[i-1].after)}
}
assert.equal(report.menuInputs.length,1);
assert.deepEqual(report.menuInputs[0],{attempt:0,captured:false,dialog:true,unified:true});
const paused=report.screenshots.find(s=>s.label==='paused').state;
assert(paused.unified&&paused.dialog&&!paused.captured);
assert(paused.widgets.some(w=>w.text==='返回车库'&&!w.disabled&&w.rect[2]>0&&w.rect[3]>0));
assert(returned.sequence>paused.sequence&&paused.sequence>impact.sequence);
assert.deepEqual([returned.mode,returned.trial,returned.loading,returned.releaseWaiting,returned.sameMission],['hangar',false,false,false,false]);
assert(returned.worldReleased&&returned.terrainReleased);
assert.deepEqual(returned.disposed,{mission:true,entries:0,radio:true,view:true,voice:true,boss:true});
const fixture=report.identity,ordinary=JSON.parse(fs.readFileSync(fixture.g1WebCpu.sourceFrozen,'utf8'));
const manifest=JSON.parse(fs.readFileSync(fixture.manifest_path,'utf8'));let payloads=0;
assert.equal(ordinary.identity.sourceCommit,'b276064942ae09c0227ec28d4cfda1d5ff006455');
for(const [name,hash]of Object.entries(fixture.identity.scripts)){
 assert.equal(sha(fs.readFileSync(path.join(fixture.source_directory,'scripts',name))),hash,name);
 const entry=manifest.files.find(f=>f.fs_path===name);assert(entry,name);
 assert.equal(sha(fs.readFileSync(path.join(fixture.source_directory,'dist/assets',entry.uuid+'-'+entry.hash+entry.ext))),hash,'payload '+name);
 if(name!=='main.lua')assert.equal(hash,ordinary.identity.scripts[name],'ordinary '+name);
 payloads++;
}
for(const [name,hash]of Object.entries(report.httpHashes))assert.equal(hash,fixture.identity.scripts[name],'recorded actual HTTP '+name);
assert.equal(Object.keys(report.httpHashes).length,8);
const artifactHashes={};for(const file of ['report.json','runtime.log',...report.screenshots.map(s=>s.file)])artifactHashes[file]=sha(fs.readFileSync(path.join(evidence,file)));
const result={status:'PASS_INDEPENDENT_RAW_EVIDENCE',evidence:path.relative(root,evidence).replaceAll('\\','/'),
 frozenOrdinary:fixture.g1WebCpu.sourceFrozen,fixtureManifest:path.basename(fixture.manifest_path),chunks,states:states.length,payloads,
 recordedActualHttpHashesVerified:report.httpHashes,impactFrame:cases[0].frame,
 impacts:cases.map(c=>({name:c.name,hitDelta:c.hitDelta,dealt:c.dealt||0,structureBefore:c.before.structure,structureAfter:c.after.structure,
  traumaBefore:c.traumaBefore,traumaAfter:c.traumaAfter,remaining:c.remaining,rayCount:Object.keys(c.rays).length})),
 actualEscapeAttempts:report.menuInputs.length,pausedSequence:paused.sequence,returnedSequence:returned.sequence,
 disposed:returned.disposed,worldReleased:returned.worldReleased,terrainReleased:returned.terrainReleased,artifactHashes,
 boundary:'Offline independent checksum reconstruction of actual root-run Web evidence. Explicit Rules.Go(2)/Events and fight state, stationary real impacts, one actual Escape and real pause-button return. No additional runtime launched; no natural S5, pixel parity, audible cue, performance or mobile acceptance.'};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
