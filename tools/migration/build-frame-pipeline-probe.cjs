'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
function validateFramePipelineOptions(argv){
 if(argv.includes('--profile-vehicle-pipeline'))assert.ok(argv.includes('--profile-before-step-pipeline'),'Vehicle pipeline requires BeforeStep mode');
 if(argv.includes('--profile-before-step-pipeline'))assert.ok(argv.includes('--profile-presentation-pipeline'),'BeforeStep pipeline requires presentation mode');
 if(argv.includes('--profile-presentation-pipeline'))assert.ok(argv.includes('--profile-frame-pipeline')&&argv.includes('--profile-fixed-step-pipeline'),'Presentation pipeline requires both frame and fixed-step pipelines');
 if(argv.includes('--profile-fixed-step-pipeline'))assert.ok(argv.includes('--profile-frame-pipeline'),'Fixed-step pipeline extends the dedicated frame pipeline');
 if(!argv.includes('--profile-frame-pipeline'))return;
 assert.ok(argv.includes('--qa')&&argv.includes('--monitor-disabled'),'Frame pipeline requires explicit --qa --monitor-disabled');
 const blocked=argv.filter(arg=>(arg.startsWith('--profile-')&&!['--profile-frame-pipeline','--profile-fixed-step-pipeline','--profile-presentation-pipeline','--profile-before-step-pipeline','--profile-vehicle-pipeline'].includes(arg))||
  /^--(?:cdp|render-experiment|warm-experiment|warm-intro-experiment|warm-batch-size|download-concurrency)(?:=|$)/.test(arg)||
  ['--story-route','--home-route','--loading-failure-test','--perf-monitor'].includes(arg));
 assert.equal(blocked.length,0,'Dedicated frame pipeline cannot mix profiles/routes/failure/CDP: '+blocked.join(' '));
 if(argv.includes('--profile-presentation-pipeline'))assert.ok(!argv.some(arg=>['--qa-aim-engine','--qa-salvage-stock','--auto-gc-aba','--allocation-owners'].includes(arg)),'Presentation pipeline cannot mix fixtures or GC diagnostics');
}
const presentationModules=['app/HangarApp.lua','app/TrialSession.lua','render/CombatView.lua','render/CombatEffects.lua','ui/DriveHud.lua'];
const beforeStepModules=['drive/Vehicle.lua','combat/EnemyDriver.lua','combat/WeaponSystem.lua','combat/BattleController.lua','combat/CarUnit.lua'];
const vehicleModules=['drive/RaySuspension.lua','drive/LegControl.lua','drive/HoverControl.lua','drive/ContactControl.lua','drive/LegHitboxes.lua'];
function pipelineSource(presentation=false,beforeStep=false,vehicle=false){
 let source=fs.readFileSync(path.join(__dirname,'qa-frame-pipeline.lua'),'utf8');
 assert.ok(!vehicle||beforeStep,'Vehicle extension requires BeforeStep mode');
 assert.ok(!beforeStep||presentation,'BeforeStep extension requires presentation mode');
 if(beforeStep){
  assert.equal(source.split('#frame.events<64').length,2,'Unique bounded event capacity');
  source=source.replace('#frame.events<64',vehicle?'#frame.events<2048':'#frame.events<1024');
 }
 if(!presentation)return source;
 assert.equal(source.split('\nreturn M').length,2,'Unique base pipeline return');
 return source.replace('\nreturn M','\n'+fs.readFileSync(path.join(__dirname,'qa-presentation-pipeline.lua'),'utf8')+(beforeStep?'\n'+fs.readFileSync(path.join(__dirname,'qa-before-step-pipeline.lua'),'utf8'):'')+(vehicle?'\n'+fs.readFileSync(path.join(__dirname,'qa-vehicle-pipeline.lua'),'utf8'):'')+'\nreturn M');
}
function buildFramePipelineProbe(prepared,options={}){
 const relative='main.lua',main=fs.readFileSync(path.join(prepared.source_directory,'scripts',relative));
 assert.equal(sha(main),prepared.identity.scripts[relative],'Frozen main entry identity');
 const presentation=options.presentation===true;
 const beforeStep=options.beforeStep===true;
 const vehicle=options.vehicle===true;
 assert.ok(!vehicle||beforeStep,'Vehicle instrumentation requires BeforeStep mode');
 assert.ok(!beforeStep||presentation,'BeforeStep instrumentation requires presentation mode');
 assert.ok(!presentation||options.fixedSteps===true,'Presentation instrumentation requires fixed-step mode');
 const source=pipelineSource(presentation,beforeStep,vehicle);
 const fixedSteps=options.fixedSteps===true;
 const fixedIdentity=[];
 if(fixedSteps)for(const name of ['combat/BattleController.lua','drive/TrackWorld.lua']){
  const hash=sha(fs.readFileSync(path.join(prepared.source_directory,'scripts',name)));
  assert.equal(hash,prepared.identity.scripts[name],'Frozen fixed-step module identity '+name);
  fixedIdentity.push('["'+name+'"]="'+hash+'"');
 }
 const identity={mainSha256:sha(main),probeSha256:sha(source),librarySource:'Engine built-in urhox-libs/UI; not the project reference copy',automaticEnable:false};
 const presentationIdentity=[];
 if(presentation)for(const name of presentationModules){
  const hash=sha(fs.readFileSync(path.join(prepared.source_directory,'scripts',name)));
  assert.equal(hash,prepared.identity.scripts[name],'Frozen presentation module identity '+name);
  presentationIdentity.push('["'+name+'"]="'+hash+'"');
 }
 const beforeStepIdentity=[];
 if(beforeStep)for(const name of beforeStepModules){
  const hash=sha(fs.readFileSync(path.join(prepared.source_directory,'scripts',name)));
  assert.equal(hash,prepared.identity.scripts[name],'Frozen BeforeStep module identity '+name);
  beforeStepIdentity.push('["'+name+'"]="'+hash+'"');
 }
 const vehicleIdentity=[];
 if(vehicle)for(const name of vehicleModules){
  const hash=sha(fs.readFileSync(path.join(prepared.source_directory,'scripts',name)));
  assert.equal(hash,prepared.identity.scripts[name],'Frozen Vehicle module identity '+name);
  vehicleIdentity.push('["'+name+'"]="'+hash+'"');
 }
 return 'do\nassert(not rawget(_G,"VOX_QA_FRAME_PIPELINE"),"Duplicate frame pipeline suffix")\n'+
  '_G.VOX_QA_PIPELINE_IDENTITY={mainSha256="'+identity.mainSha256+'",probeSha256="'+identity.probeSha256+'",automaticEnable=false,callbackOwner="lexical-entry"'+(fixedSteps?',fixedSteps=true,fixedStepSources={'+fixedIdentity.join(',')+'}':'')+(presentation?',presentationPipeline=true,presentationSources={'+presentationIdentity.join(',')+'}':'')+(beforeStep?',beforeStepPipeline=true,beforeStepSources={'+beforeStepIdentity.join(',')+'}':'')+(vehicle?',vehiclePipeline=true,vehicleSources={'+vehicleIdentity.join(',')+'}':'')+'}\n'+
  '_G.VOX_QA_FRAME_PIPELINE=(function()\n'+source+'\nend)()\n_G.VOX_QA_PIPELINE_IDENTITY=nil\n'+
  'local callbacks={HandleUpdate=HandleUpdate,HandlePostUpdate=HandlePostUpdate,HandleFramePresented=HandleFramePresented}\n'+
  '_G.VOX_QA_FRAME_PIPELINE.Prepare(callbacks'+(fixedSteps?',true':'')+')\n'+
  (presentation?'_G.VOX_QA_FRAME_PIPELINE.PreparePresentation()\n':'')+
  (beforeStep?'_G.VOX_QA_FRAME_PIPELINE.PrepareBeforeStep()\n':'')+
  (vehicle?'_G.VOX_QA_FRAME_PIPELINE.PrepareVehicle()\n':'')+
  'HandleUpdate=callbacks.HandleUpdate;HandlePostUpdate=callbacks.HandlePostUpdate;HandleFramePresented=callbacks.HandleFramePresented\nend\n';
}
module.exports={buildFramePipelineProbe,validateFramePipelineOptions,pipelineSource,presentationModules,beforeStepModules,vehicleModules};
if(require.main===module){
 assert.equal(process.argv.length,4,'Usage: node build-frame-pipeline-probe.cjs prepared-identity.json output-suffix.lua');
 const prepared=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
 fs.writeFileSync(process.argv[3],buildFramePipelineProbe(prepared));
 console.log('Built disabled QA frame pipeline suffix: '+path.resolve(process.argv[3]));
}
