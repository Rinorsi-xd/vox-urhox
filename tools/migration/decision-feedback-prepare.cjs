'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const stages=['hold-zero','hold-half','hold-full','decided-early','decided-late'];
const imageSizes={machinist_idle:[2304,2304],machinist_hero:[2304,2304],'company-emblem':[261,263]};
function prepare(argv){
 const options=require('./g1-web-cpu-prepare.cjs').options(argv);
 assert(options.frozen&&options.out);assert.deepEqual(Object.keys(options).sort(),['frozen','out','variants']);assert(options.variants.length<=1);
 const variants=new Map(options.variants.map(value=>{const at=value.indexOf('=');assert(at>0);const name=value.slice(0,at);assert.equal(name,'ui/IntroPromo.lua','Only the reviewed hold-layout module may vary');return [name,value.slice(at+1)];}));
 const frozen=JSON.parse(fs.readFileSync(path.resolve(root,options.frozen),'utf8'));
 assert.equal(path.basename(frozen.manifest_path),'manifest-a06e4f85.json','Unified latest reviewed freeze');
 const reference=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/evidence/intro-decision-fx-offline.json'),'utf8'));assert.equal(reference.result,'PASS');
 const modules={};for(const name of ['ui/IntroPromo.lua','ui/IntroDecisionFx.lua','ui/SourceDraw.lua','ui/IntroOpacity.lua','controls/TouchMode.lua','app/ResourceGate.lua']){
  const bytes=fs.readFileSync(variants.has(name)?path.resolve(root,variants.get(name)):path.join(frozen.source_directory,'scripts',name));const hash=sha(bytes);if(!variants.has(name))assert.equal(hash,frozen.identity.scripts[name],name);
  if(reference.sha256['scripts/'+name])assert.equal(hash,reference.sha256['scripts/'+name],'Offline-tested repair '+name);modules[name]=hash;
 }
 const sourceManifest=JSON.parse(fs.readFileSync(frozen.manifest_path));
 const resources={},engineReferences={};for(const name of ['Intro/Intro.json','Intro/Images/machinist_idle.png','Intro/Images/machinist_hero.png','Intro/Images/company-emblem.png',
  'Fonts/VoxIndustrial-Bold.otf','Fonts/BarlowCondensed-BoldItalic.ttf','Fonts/VoxDisplayTabular-BoldItalic.ttf','Fonts/SmileySans-Oblique.ttf','Fonts/Anonymous Pro.ttf']){
  const entry=sourceManifest.files.find(file=>file.fs_path===name);assert(entry,'Frozen resource '+name);
  if(entry.source==='engine-res'){assert.equal(entry.hash,undefined);engineReferences[name]=entry;continue;}
  const bytes=fs.readFileSync(path.join(frozen.source_directory,'dist/assets',entry.uuid+'-'+entry.hash+entry.ext));resources[name]=sha(bytes);
  const short=path.basename(name,'.png');if(imageSizes[short]){assert.equal(bytes.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.deepEqual([bytes.readUInt32BE(16),bytes.readUInt32BE(20)],imageSizes[short],'Frozen actual PNG dimensions '+name);}
 }
 const probe=path.join(__dirname,'decision-feedback-render.lua');
 const sourceBaseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
 const sourceFiles={};for(const name of ['shared/css/style.css','shared/css/new-ui-tokens.css','shared/css/intro.css','three/src/intro/intro.js']){
  const hash=sha(fs.readFileSync(path.join(sourceBaseline.snapshot,name)));assert.equal(hash,sourceBaseline.files[name].sha256);sourceFiles[name]=hash;
 }
 assert(reference.source.dom.holdHTML);const sourceHold={html:reference.source.dom.holdHTML,files:sourceFiles,commit:sourceBaseline.commit};
 const prepared=require('./g1-web-cpu-prepare.cjs').prepare(['--frozen',options.frozen,'--out',options.out,'--scenario','lanes','--steps','60','--warmup','0','--probe-file',probe,...options.variants.flatMap(value=>['--variant',value])]);
 prepared.decisionFeedback={isolated:true,kind:'rendered-functional-fixture',modules,resources,engineReferences,imageSizes,sourceHold,stages,probeSha256:sha(fs.readFileSync(probe)),
  boundary:'Dedicated derived main, unchanged frozen IntroPromo/fonts/images. Synthetic five-stage clocks only; no App/gameplay/audio/inventory/save or performance claim.'};
 fs.writeFileSync(path.join(prepared.source_directory,'identity.json'),JSON.stringify(prepared,null,2)+'\n');return prepared;
}
module.exports={prepare,stages,imageSizes};
if(require.main===module){try{const r=prepare(process.argv.slice(2));console.log(JSON.stringify({status:'PREPARED_NOT_RUN',identity:path.join(r.source_directory,'identity.json'),fixture:r.decisionFeedback}))}catch(error){console.error(error.stack);process.exitCode=1}}
