// Read-only package/content audit; writes only its independent evidence JSON.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const snapshot=path.resolve(root,process.argv[2]||'.tmp/outgame-cached-1792079256939');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const json=file=>JSON.parse(fs.readFileSync(file,'utf8'));
const prepared=json(path.join(snapshot,'identity.json')),identity=prepared.identity;
const manifest=json(prepared.manifest_path);
function payloadHash(row){
 const file=path.resolve(path.dirname(prepared.manifest_path),'..','assets',`${row.uuid}-${row.hash}${row.ext}`);
 return fs.existsSync(file)?hash(file):null;
}
function luaHashes(base){const out={};for(const entry of fs.readdirSync(base,{recursive:true,withFileTypes:true})){if(entry.isFile()&&entry.name.endsWith('.lua')){const file=path.join(entry.parentPath,entry.name);out[path.relative(base,file).replaceAll('\\','/')]=hash(file);}}return out;}
const current=luaHashes(path.join(root,'scripts')),packed=luaHashes(path.join(snapshot,'scripts'));
const problems=[];
for(const name of new Set([...Object.keys(current),...Object.keys(packed),...Object.keys(identity.scripts)])){
 if(!current[name]||current[name]!==packed[name]||packed[name]!==identity.scripts[name])problems.push({name,current:current[name]||null,snapshot:packed[name]||null,identity:identity.scripts[name]||null});
}
const fingerprint=crypto.createHash('sha256').update(JSON.stringify(Object.entries(packed).sort())).digest('hex');
if(fingerprint!==identity.scriptFingerprint)problems.push({name:'scriptFingerprint',expected:identity.scriptFingerprint,actual:fingerprint});
const manifestLua=manifest.files.filter(file=>file.ext==='.lua');
const manifestLuaProblems=[];
const luaPayloads=[];
for(const name of Object.keys(packed)){
 const rows=manifestLua.filter(file=>file.fs_path===name);
 if(rows.length!==1||rows[0].size!==fs.statSync(path.join(snapshot,'scripts',name)).size)manifestLuaProblems.push({name,entries:rows});
 if(rows.length===1){
  const row=rows[0],actual=payloadHash(row);
  const pass=actual===packed[name]&&row.groups.includes('#blocking');
  luaPayloads.push({name,sha256:actual,expected:packed[name],blocking:row.groups.includes('#blocking'),pass});
  if(!pass)manifestLuaProblems.push({name,expected:packed[name],actual,groups:row.groups});
 }
}
for(const file of manifestLua)if(!packed[file.fs_path])manifestLuaProblems.push({name:file.fs_path,unexpected:true});
const reports=['match-target','combat-result-production','workshop-shop','story-result-quote','story-input-progress','story-result-rows','g5-result','g5-edit-touch','match-actions','tutorial-presentation','intro-driver-actions','inventory-layout','inventory-detail','story-boss-allies','turret-deletion','inventory-scroll','endless-banner','livery-touch','workshop-lifecycle','story-boss-kneel','endless-view-contract','part-hit-flash','endless-spawn-lifetime','trial-event-boundary','math-scalar','story-boss-waypoint','flash-warmup','salvage-vault','repair-symbol','story-boss-kneel-dialogue','leg-feel','g5-extraction','story-boss-combat-flow','turret-bounds-profile','turret-aabb-boundaries','endless-spawn-cache','aim-lines-render','story-choice-epilogue','leg-target-scalar'];
reports.push('ui-sounds','action-buttons','story-comms-cues','build-sounds','button-keyboard','selection-bar','story-objective');
reports.push('story-choice-presentation','touch-erase');
reports.push('opening-construction','opening-prefetch','story-death-order');
reports.push('intro-contract');
reports.push('comms-portraits');
reports.push('intro-portrait-handoff');
reports.push('intro-scene-capture','intro-idyll-warmup');
reports.push('intro-comic-motion');
// Earlier old/current draw-equivalence reports remain historical files; the
// source-authored style completion is covered by these actual current draws.
const currentBatchReports=new Set(['opening-construction','opening-prefetch','intro-audio-envelope','intro-brand','intro-familiar','intro-noncaption-text','intro-sortie-feedback','intro-timing','intro-promo','intro-runtime','game-audio-context','intro-contract-current-style','render-target-retirement','intro-gate','intro-finish','intro-promo-motion-current-style','intro-audio-tail','intro-qa-tools','intro-mix-transitions','intro-voice-clock','intro-gc-fence','web-map-transition']);
currentBatchReports.add('intro-promo-fx');
currentBatchReports.add('intro-comic-motion');
currentBatchReports.add('intro-payslip-layers');
currentBatchReports.add('story-page-lifecycle');
currentBatchReports.add('weapon-loops');
currentBatchReports.add('opening-host-residuals');
currentBatchReports.add('intro-actor-checkpoints');
currentBatchReports.add('salvage-encounter-feedback');
currentBatchReports.add('salvage-loot-feedback');
currentBatchReports.add('body-arm');
currentBatchReports.add('intro-recruit-audio');
currentBatchReports.add('opening-budget-staging');
currentBatchReports.add('story-boss-exposed');
currentBatchReports.add('story-boss-defeat');
currentBatchReports.add('story-boss-barks');
currentBatchReports.add('story-mission-timers');
currentBatchReports.add('story-dead-player-park');
currentBatchReports.add('ambience-audio');
currentBatchReports.add('practice-course');
currentBatchReports.add('loader-background-arrays');
currentBatchReports.add('story-touch-prompt');
currentBatchReports.add('hangar-cue-hooks');
currentBatchReports.add('intro-comic-cues');
currentBatchReports.add('epilogue-pages');
currentBatchReports.add('match-mvp-audio');
currentBatchReports.add('story-boss-recovery');
currentBatchReports.add('story-boss-impact');
currentBatchReports.add('story-boss-cinematic-input');
currentBatchReports.add('intro-recruit-exits');
currentBatchReports.add('intro-comic-impact');
currentBatchReports.add('driving-loops');
currentBatchReports.add('match-radio-dsp');
currentBatchReports.add('audio-panel-duck');
currentBatchReports.add('intro-comms-unfold');
currentBatchReports.add('story-car-size');
currentBatchReports.add('story-comms-fallback');
currentBatchReports.add('story-zone-progress');
currentBatchReports.add('story-boss-rise-warning');
currentBatchReports.add('story-boss-pod-motion');
currentBatchReports.add('combat-warmup-postupdate');
currentBatchReports.add('story-voice-scope');
currentBatchReports.add('endless-checkpoint');
currentBatchReports.add('intro-terminal-impact');
currentBatchReports.add('combat-warmup-mask-work');
currentBatchReports.add('combat-warmup-signature');
currentBatchReports.add('intro-tvcut-lowpass');
currentBatchReports.add('story-natural-object-samples');
currentBatchReports.add('story-road-route');
currentBatchReports.add('story-navigation');
currentBatchReports.add('battle-object-probe');
currentBatchReports.add('story-probe-compact');
currentBatchReports.add('feedback-death-lifecycle');
currentBatchReports.add('epilogue-stamp-motion');
currentBatchReports.add('audio-completion-boundary');
currentBatchReports.add('battle-update-timing');
currentBatchReports.add('battle-flow-preparation');
currentBatchReports.add('battle-spawn-timing');
currentBatchReports.add('g5-cloud-recovery');
currentBatchReports.add('car-unit-read-work');
currentBatchReports.add('kill-presentation');
currentBatchReports.add('match-map-bake');
currentBatchReports.add('salvage-exit-contract');
currentBatchReports.add('salvage-presentation-time');
currentBatchReports.add('debug-panel');
currentBatchReports.add('salvage-loadout-feedback');
currentBatchReports.add('home-assembly');
currentBatchReports.add('lobby-loading');
currentBatchReports.add('salvage-departure');
currentBatchReports.add('spawn-view-cache');
currentBatchReports.add('nav-distance-work');
currentBatchReports.add('story-route-observer');
currentBatchReports.add('build-input-consumer');
currentBatchReports.add('battle-view-lifetime');
currentBatchReports.add('salvage-quantity');
currentBatchReports.add('story-feedback');
currentBatchReports.add('story-install-death');
for(const name of currentBatchReports)if(!reports.includes(name))reports.push(name);
const fixtures=[];
const fixtureAssets=new Set();
for(const name of reports){
 const file='docs/migration/evidence/'+name+'-offline.json',data=json(path.join(root,file)),files=[];
 for(const relative of data.approvedSourceAssets||[])fixtureAssets.add(relative.startsWith('assets/')?relative:'assets/'+relative);
 for(const field of ['productionHashes','production','scripts','resources','inputs','testInputs','apiReferenceHashes','evidenceReportHashes']){
  for(const [key,expected] of Object.entries(data[field]||{})){
   if(typeof expected!=='string'||!/^[a-f0-9]{64}$/i.test(expected))continue;
   const normalized=key.replaceAll('\\','/');
   const historicalFixture=normalized.startsWith('docs/migration/evidence/history/');
   if(normalized.startsWith('tools/')||historicalFixture||field==='apiReferenceHashes'||field==='evidenceReportHashes'){
    const file=path.join(root,normalized),actual=fs.existsSync(file)?hash(file):null;
    files.push({path:normalized,scope:field==='evidenceReportHashes'?'evidence-report':field==='apiReferenceHashes'?'evidence-api-reference':historicalFixture?'evidence-fixture':'evidence-tool',expected,actual,packageHash:null,pass:expected.toLowerCase()===actual});
    continue;
   }
   const relative=normalized.startsWith('scripts/')||normalized.startsWith('assets/')?normalized:(field==='resources'?'assets/':'scripts/')+normalized;
   if(relative.startsWith('assets/'))fixtureAssets.add(relative);
   const source=path.join(root,relative),target=path.join(snapshot,relative);
   const actual=fs.existsSync(source)?hash(source):null,packageHash=fs.existsSync(target)?hash(target):null;
   files.push({path:relative,scope:'packaged-production',expected,actual,packageHash,pass:expected.toLowerCase()===actual&&actual===packageHash});
  }
 }
 if(data.payslipTile){
  const relative=data.payslipTile.path,expected=data.payslipTile.sha256;
  fixtureAssets.add(relative);
  const actual=hash(path.join(root,relative)),packageHash=hash(path.join(snapshot,relative));
  files.push({path:relative,scope:'packaged-production',expected,actual,packageHash,pass:expected===actual&&actual===packageHash});
 }
 fixtures.push({report:file,reportSha256:hash(path.join(root,file)),scope:currentBatchReports.has(name)?'current-opening-batch':'historical-regression',result:data.result??data.status??(data.pass===true?'PASS':'FAIL'),checks:Array.isArray(data.checks)?data.checks.length:data.checks??data.assertions,files:files.length,packagedProductionFiles:files.filter(f=>f.scope==='packaged-production').length,evidenceToolFiles:files.filter(f=>f.scope==='evidence-tool').length,apiReferenceFiles:files.filter(f=>f.scope==='evidence-api-reference').length,passed:files.filter(f=>f.pass).length,drift:files.filter(f=>!f.pass)});
}
function resourceAudit(relative){
 const currentHash=hash(path.join(root,relative)),snapshotHash=hash(path.join(snapshot,relative));
 const entries=manifest.files.filter(file=>file.fs_path===relative.slice(7));
 const emittedHash=entries.length===1?payloadHash(entries[0]):null;
 return {path:relative,currentHash,snapshotHash,emittedHash,pass:currentHash===snapshotHash&&snapshotHash===emittedHash&&entries.length===1&&entries[0].size===fs.statSync(path.join(snapshot,relative)).size,manifest:entries};
}
const resources=[...new Set(['assets/UI/Outgame.json','assets/UI/SalvageRules.json','assets/Story/Mission/ResultVoices.json','assets/Intro/Fonts/TitleGlyphs.json','assets/Intro/Fonts/Font.json','assets/Intro/Fonts/GameFont.ttf','assets/Intro/Intro.json','assets/UI/SourceFontMetrics.json','assets/UI/SourceIcons.json',...fixtureAssets])].map(resourceAudit);
const fonts=[...new Set([...manifest.files.filter(file=>!file.source&&file.fs_path.startsWith('Fonts/')&&/\.(ttf|otf)$/.test(file.ext)).map(file=>'assets/'+file.fs_path),'assets/Fonts/VoxRepairSymbols-OFL.txt','assets/Fonts/VoxRepairSymbols-PROVENANCE.json'])].map(resourceAudit);
const voiceRegistry=json(path.join(snapshot,'assets/Story/Mission/ResultVoices.json'));
const baseline=json(path.join(root,'docs/migration/outgame-baseline.json'));
const voices=Object.entries(voiceRegistry.voices).map(([id,voice])=>{
 const relative='assets/'+voice.path,bytes=fs.readFileSync(path.join(snapshot,relative));
 const currentHash=hash(path.join(root,relative)),snapshotHash=hash(path.join(snapshot,relative));
 const original='shared/assets/story/vo/'+id+'.mp3',sourceHash=hash(path.join(baseline.snapshot,original));
 const entries=manifest.files.filter(file=>file.fs_path===voice.path);
 const emittedHash=entries.length===1?payloadHash(entries[0]):null;
 const ogg=bytes.subarray(0,4).toString('ascii')==='OggS';
 return {id,path:relative,currentHash,snapshotHash,emittedHash,derivedHash:voice.derivedSha256,sourceHash,ogg,manifest:entries,pass:currentHash===snapshotHash&&snapshotHash===emittedHash&&snapshotHash===voice.derivedSha256&&sourceHash===voice.sha256&&sourceHash===baseline.files[original].sha256&&ogg&&entries.length===1&&entries[0].size===bytes.length};
});
function cuePayloads(registry){
 const registryPath=path.join(snapshot,registry);
 return fs.existsSync(registryPath)?Object.entries(json(registryPath).cues).map(([id,cue])=>{
 const relative='assets/'+cue.path,bytes=fs.readFileSync(path.join(snapshot,relative));
 const currentHash=hash(path.join(root,relative)),snapshotHash=hash(path.join(snapshot,relative));
 const sourceHash=hash(path.join(baseline.snapshot,cue.source));
 const entries=manifest.files.filter(file=>file.fs_path===cue.path),emittedHash=entries.length===1?payloadHash(entries[0]):null;
 const wav=bytes.subarray(0,4).toString('ascii')==='RIFF'&&bytes.subarray(8,12).toString('ascii')==='WAVE';
 return {id,path:relative,currentHash,snapshotHash,emittedHash,source:cue.source,sourceHash,wav,bytes:bytes.length,pass:currentHash===snapshotHash&&snapshotHash===emittedHash&&snapshotHash===sourceHash&&sourceHash===cue.sha256&&(cue.bytes===undefined||bytes.length===cue.bytes)&&wav&&entries.length===1&&entries[0].size===bytes.length};
 }):[];
}
const uiSounds=cuePayloads('assets/UI/Sounds.json'),radioSounds=cuePayloads('assets/Story/Radio/Radio.json');
const matchRadioRegistry=json(path.join(snapshot,'assets/Combat/MatchRadioDSP.json'));
const matchRadioFiles=new Map();
for(const line of Object.values(matchRadioRegistry.lines))for(const stem of Object.values(line.stems))matchRadioFiles.set(stem.path,stem);
const matchRadioSounds=[...matchRadioFiles].map(([name,stem])=>{
 const relative='assets/'+name,currentHash=hash(path.join(root,relative)),snapshotHash=hash(path.join(snapshot,relative));
 const entries=manifest.files.filter(file=>file.fs_path===name),emittedHash=entries.length===1?payloadHash(entries[0]):null;
 const preloaded=entries.some(row=>(row.groups||[]).some(group=>manifest.preload_groups.includes(group)||group==='#blocking'));
 return {path:relative,currentHash,snapshotHash,emittedHash,expected:stem.sha256,preloaded,
  pass:currentHash===snapshotHash&&snapshotHash===emittedHash&&snapshotHash===stem.sha256&&entries.length===1&&!preloaded};
});
const matchRadioInputs=Object.entries(matchRadioRegistry.inputs).map(([name,expected])=>{
 const actual=hash(path.join(baseline.snapshot,name));
 return {path:name,expected,actual,pass:expected===actual&&expected===baseline.files[name]?.sha256};
});
const introTvCutSource=json(path.join(root,'docs/migration/evidence/intro-tvcut-lowpass-source.json'));
const introTvCutConfig=json(path.join(snapshot,'assets/Intro/Intro.json'));
const introTvCutDerived=resourceAudit('assets/'+introTvCutSource.output.path);
const introTvCutRaw=resourceAudit('assets/Intro/Audio/sfx_tv_cut.mp3');
const introTvCutInputs=Object.entries(introTvCutSource.provenance).map(([name,expected])=>{
 const actual=hash(path.join(baseline.snapshot,name));
 return {path:name,expected,actual,pass:expected===actual&&expected===baseline.files[name]?.sha256};
});
const introTvCut={sourceReport:'docs/migration/evidence/intro-tvcut-lowpass-source.json',sourceReportSha256:hash(path.join(root,'docs/migration/evidence/intro-tvcut-lowpass-source.json')),derived:introTvCutDerived,raw:introTvCutRaw,inputs:introTvCutInputs,
 pass:introTvCutSource.result==='PASS'&&introTvCutInputs.every(row=>row.pass)&&introTvCutDerived.pass&&introTvCutRaw.pass&&introTvCutDerived.emittedHash===introTvCutSource.output.sha256&&introTvCutRaw.emittedHash===introTvCutSource.provenance['shared/assets/intro/audio/sfx_tv_cut.mp3']&&introTvCutConfig.audioDsp['tv_cut:1800']==='sfx_tv_cut_lowpass1800'&&introTvCutConfig.audio.sfx_tv_cut_lowpass1800===introTvCutSource.output.path&&introTvCutConfig.audio.sfx_tv_cut==='Intro/Audio/sfx_tv_cut.mp3'&&introTvCutSource.toolSha256===hash(path.join(root,'tools/migration/import-intro-tvcut-lowpass.cjs'))};
const controller=fs.readFileSync(path.join(snapshot,'scripts/combat/BattleController.lua'),'utf8');
const targetDelegationPath=path.join(root,'docs/migration/evidence/battle-target-delegation-offline.json');
const targetDelegation=fs.existsSync(targetDelegationPath)?json(targetDelegationPath):null;
const delegationMutations=['hot-require','wrong-arguments','dropped-tail-returns','skipped-selection'];
const delegationVerified=targetDelegation?.result==='PASS'&&targetDelegation.checks>=9&&
 targetDelegation.productionHashes?.['scripts/combat/BattleController.lua']===packed['combat/BattleController.lua']&&
 targetDelegation.toolSha256===hash(path.join(root,'tools/migration/check-battle-target-delegation.py'))&&
 delegationMutations.every(name=>targetDelegation.negativeControls?.some(row=>row.name===name&&row.rejected===true));
const wiring={moduleInIdentity:identity.scripts['combat/MatchTarget.lua']===packed['combat/MatchTarget.lua'],moduleInManifest:manifestLua.some(f=>f.fs_path==='combat/MatchTarget.lua'),delegation:delegationVerified,goalInput:controller.includes('self.objectives:Goal(entry,self:Pick(entry))'),driverInput:controller.includes('entry.driver:Step(dt,goal,charge)')};
const report={result:problems.length||manifestLuaProblems.length||resources.some(r=>!r.pass)||fonts.some(r=>!r.pass)||voices.length!==12||voices.some(v=>!v.pass)||uiSounds.some(v=>!v.pass)||radioSounds.some(v=>!v.pass)||Object.values(wiring).some(v=>!v)?'FAIL':'PASS',snapshot,manifest:path.basename(prepared.manifest_path),scriptFingerprint:fingerprint,sourceCommit:identity.sourceCommit,targetCommit:identity.targetCommit,counts:{currentLua:Object.keys(current).length,snapshotLua:Object.keys(packed).length,identityLua:Object.keys(identity.scripts).length,manifestLua:manifestLua.length,luaPayloads:luaPayloads.length,luaPayloadPass:luaPayloads.filter(p=>p.pass).length,manifestFiles:manifest.files.length},problems,manifestLuaProblems,luaPayloads,resources,fonts,voices,uiSounds,radioSounds,wiring,fixtures,fixtureFiles:fixtures.reduce((n,f)=>n+f.files,0),fixtureDrift:fixtures.reduce((n,f)=>n+f.drift.length,0),boundary:'SHA256/package-presence and actual emitted Lua/font/license/config/shader/voice/UI-sound/radio-sound payload audit, plus static wiring only. Fixture hash freshness does not rerun behavior tests. OGG/WAV header/content identity does not prove decoded playback or audio continuity. No GPU/browser/native/performance acceptance.'};
const out=path.join(root,'docs/migration/evidence/unified-snapshot-'+path.basename(prepared.manifest_path,'.json')+'-audit.json');
report.targetDelegation={report:path.relative(root,targetDelegationPath).replaceAll('\\','/'),sha256:targetDelegation?hash(targetDelegationPath):null,verified:delegationVerified,boundary:'Real controller Pick execution and rejected hot-path require/wrong-argument/return/skip mutations, tied to the frozen controller and current tool SHA. Other goal/driver wiring remains static; no complete match or performance acceptance.'};
report.matchRadioSounds=matchRadioSounds;report.matchRadioInputs=matchRadioInputs;
report.introTvCut=introTvCut;if(!introTvCut.pass)report.result='FAIL';
if(matchRadioSounds.length===0||matchRadioSounds.some(row=>!row.pass)||matchRadioInputs.some(row=>!row.pass))report.result='FAIL';
if(fixtures.some(f=>!['PASS','PASSED'].includes(f.result)||f.files===0||f.drift.length))report.result='FAIL';
const scopeResult=scope=>fixtures.filter(f=>f.scope===scope).some(f=>!['PASS','PASSED'].includes(f.result)||f.files===0||f.drift.length)?'FAIL':'PASS';
report.currentBatchResult=scopeResult('current-opening-batch');
report.historicalRegressionResult=scopeResult('historical-regression');
report.scopeBoundary='Current opening batch reports are explicitly registered and tied to report bytes and production/package hashes. tools/ entries and apiReferenceHashes are separately counted as evidence-tool and evidence-api-reference associations and checked against workspace bytes only; they are not packaged production and have no packageHash. Historical regressions remain in fixtures and continue to fail the overall result when stale or failing. Scope results establish hash freshness only; they do not rerun report behavior or prove rendered parity.';
const historyDir=path.join(root,'docs/migration/evidence/history-'+path.basename(prepared.manifest_path,'.json')+'-pre-refresh');
report.preservedHistoricalEvidence=fs.existsSync(historyDir)?fs.readdirSync(historyDir).filter(name=>name.endsWith('.json')).map(name=>{const file=path.join(historyDir,name),data=json(file);return {report:path.relative(root,file).replaceAll('\\','/'),sha256:hash(file),result:data.result??data.status??(data.pass===true?'PASS':'FAIL'),fixtureDrift:data.fixtureDrift??null};}):[];
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,luaPayloads:undefined,fixtures:fixtures.map(({drift,...row})=>({...row,drift})),evidence:out},null,2));
if(report.result!=='PASS')process.exitCode=1;
