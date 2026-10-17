'use strict';
// Root-only hardware runner. Request-local QA suffix; immutable f881 package.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm'),Module=require('node:module');
const recovered=require('./run-load-heap-model-wait-recovered.cjs');
const suffix=fs.readFileSync(path.join(__dirname,'probe-salvage-holder-occlusion.lua'),'utf8');
function once(s,n,r){assert.equal(s.split(n).length,2,'Unique holder QA boundary '+n.slice(0,80));return s.replace(n,r)}
function runnerSource(original){
 let s=recovered.runnerSource(original);
 s=once(s,'function sourceSuffix(){return baseSuffix()+built().suffix}','function sourceSuffix(){return baseSuffix()+built().suffix+'+JSON.stringify('\n'+suffix)+'}');
 s=once(s,"const at=line.indexOf('OUTGAME_STATE ');if(at>=0)","const holderAt=line.indexOf('VOX_QA_HOLDER_OCCLUSION ');if(holderAt>=0){report.holderToggles=report.holderToggles||[];report.holderToggles.push(JSON.parse(line.slice(holderAt+24)));persist()}\n   const at=line.indexOf('OUTGAME_STATE ');if(at>=0)");
 s=once(s,"await op('activated screenshot outside allocator queries',()=>page.screenshot({path:path.join(out,'activated.png'),timeout:10000}));",String.raw`await op('activated screenshot outside allocator queries',()=>page.screenshot({path:path.join(out,'activated.png'),timeout:10000}));
  await op('QA temporarily hide holder',()=>page.keyboard.press('ScrollLock'));await fresh();
  check(state.salvageRun.cine.view.frameVisible===false,'QA holder actually hidden');
  report.holderHiddenState=structuredClone(state);
  await op('hidden holder screenshot',()=>page.screenshot({path:path.join(out,'holder-hidden.png'),timeout:10000}));
  await op('QA restore holder',()=>page.keyboard.press('ScrollLock'));await fresh();
  check(state.salvageRun.cine.view.frameVisible===true,'QA holder actually restored');
  report.holderRestoredState=structuredClone(state);
  await op('restored holder screenshot',()=>page.screenshot({path:path.join(out,'holder-restored.png'),timeout:10000}));
  assert.deepEqual(report.holderToggles.map(row=>row.visible),[false,true]);`);
 return s;
}
module.exports={runnerSource};
if(require.main===module){
 const file=path.join(__dirname,'run-load-heap-boundary-short.cjs'),source=fs.readFileSync(file,'utf8');
 if(process.argv.includes('--self-test')){assert.deepEqual(process.argv.slice(2),['--self-test']);new vm.Script(runnerSource(source));assert.throws(()=>runnerSource(source.replace('function sourceSuffix(){return baseSuffix()+built().suffix}','drift')));assert.equal('VOX_QA_HOLDER_OCCLUSION '.length,24);console.log('PASS: QA holder adapter syntax, immutable origin/request suffix separation and drift rejection; no hardware launched')}
 else{assert.deepEqual(process.argv.slice(2),[]);process.env.VOX_PREPARE_FILE='.tmp/outgame-cached-1792189057538/identity.json';const m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(__dirname);m._compile(runnerSource(source),file);m.exports.run().catch(error=>{console.error(error.stack);process.exitCode=1})}
}
