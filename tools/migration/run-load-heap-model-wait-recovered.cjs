'use strict';
// QA transport recovery only; original baseline and failed evidence stay immutable.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),Module=require('node:module'),vm=require('node:vm');
const model=require('./run-load-heap-model-wait.cjs');
function once(source,needle,replacement){assert.equal(source.split(needle).length,2,'Unique recovery boundary '+needle.slice(0,80));return source.replace(needle,replacement)}
function missingContainerEnd(raw){
 if(!raw.trimStart().startsWith('{')||raw.trimEnd().endsWith('}'))return false;
 const stack=[];let quoted=false,escaped=false;
 for(const char of raw){
  if(quoted){if(escaped)escaped=false;else if(char==='\\')escaped=true;else if(char==='"')quoted=false;continue}
  if(char==='"'){quoted=true;continue}
  if(char==='{'||char==='[')stack.push(char);
  else if(char==='}'||char===']'){if(stack.pop()!==(char==='}'?'{':'['))return false}
 }
 return stack.length>0;
}
function transport(report){
 report.stateTransportWarnings=[];
 return {
  parse(raw,seq,previous,line){
   try{
    const state=JSON.parse(raw),recoveredBySequence=seq+1;
    for(const warning of report.stateTransportWarnings)if(!warning.recoveredBySequence&&recoveredBySequence>warning.seqBefore){warning.recoveredBySequence=recoveredBySequence;warning.recoveredStage={mode:state.mode,phase:state.loading?.phase,pending:state.loading?.pending}}
    return {state,seq:recoveredBySequence};
   }catch(error){
    if(error instanceof SyntaxError&&error.message==='Unexpected end of JSON input'&&missingContainerEnd(raw)&&report.stateTransportWarnings.length<3){
     report.stateTransportWarnings.push({kind:'state-transport-truncated',error:error.message,raw,line,seqBefore:seq,previousStage:{mode:previous?.mode,phase:previous?.loading?.phase,pending:previous?.loading?.pending},rawLog:'runtime.log'});
    }else report.probeErrors.push({kind:'state',error:error.message,length:line.length,raw});
    return null;
   }
  },
  verify(){assert.ok(report.stateTransportWarnings.length<=3);assert.ok(report.stateTransportWarnings.every(w=>Number.isInteger(w.recoveredBySequence)&&w.recoveredBySequence>w.seqBefore),'Every truncated state recovered by a later complete snapshot');assert.equal(report.probeErrors.length,0,'No other malformed QA or heap records')}
 };
}
function runnerSource(original){
 let source=model.runnerSource(original);
 source=once(source,"let browser,page,server,state,seq=0,closing,totalTimer,raidTimer;","let browser,page,server,state,seq=0,closing,totalTimer,raidTimer;\n const stateTransport=require('./run-load-heap-model-wait-recovered.cjs').transport(report);\n report.stateTransportPolicy={maximumWarnings:3,requiresLaterCompleteSequence:true,heapErrorsRemainFatal:true,adapterSha256:sha(fs.readFileSync(path.join(__dirname,'run-load-heap-model-wait-recovered.cjs')))};");
 source=once(source,"const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify({seq,state})+'\\n')}catch(error){report.probeErrors.push({kind:'state',error:error.message,length:line.length});persist()}}",String.raw`const at=line.indexOf('OUTGAME_STATE ');if(at>=0){const accepted=stateTransport.parse(line.slice(at+14),seq,state,line);if(accepted){state=accepted.state;seq=accepted.seq;fs.appendFileSync(path.join(out,'states.jsonl'),JSON.stringify({seq,state})+'\n')}persist()}`);
 source=once(source,"check(report.boundaries.some(row=>row.tag==='activation-closed'),'Actual deployment Close boundary recorded');",String.raw`check(report.boundaries.some(row=>row.tag==='activation-closed'),'Actual deployment Close boundary recorded');
  await fresh();report.activatedScreenshotState=structuredClone(state);
  await op('activated screenshot outside allocator queries',()=>page.screenshot({path:path.join(out,'activated.png'),timeout:10000}));`);
 source=once(source,"check(report.httpErrors.length===0,'No HTTP failures');check(report.errors.length===0,'No Runtime errors');check(report.probeErrors.length===0,'No unparsed QA/heap records');","stateTransport.verify();check(report.stateTransportWarnings.every(w=>w.recoveredBySequence>w.seqBefore),'Every bounded truncated state recovered');\n  check(report.httpErrors.length===0,'No HTTP failures');check(report.errors.length===0,'No Runtime errors');check(report.probeErrors.length===0,'No unparsed QA/heap records');");
 source=once(source,"await op('final screenshot outside allocator queries',()=>page.screenshot", "await fresh();stateTransport.verify();report.returnedScreenshotState=structuredClone(state);\n  await op('final screenshot outside allocator queries',()=>page.screenshot");
 return source;
}
function selfTest(){
 const source=fs.readFileSync(path.join(__dirname,'run-load-heap-boundary-short.cjs'),'utf8');new vm.Script(runnerSource(source));assert.throws(()=>runnerSource(source.replace('let browser,page,server,state,seq=0,closing,totalTimer,raidTimer;','drift')));
 const make=()=>{const report={probeErrors:[]};return {report,reader:transport(report)}};
 const normal=make();assert.deepEqual(normal.reader.parse('{"mode":"trial"}',4,null,'complete'),{state:{mode:'trial'},seq:5});normal.reader.verify();
 const recovered=make();assert.equal(recovered.reader.parse('{"nested":{"rows":[1,',7,{mode:'hangar',loading:{phase:'ready'}},'raw line'),null);assert.equal(recovered.report.stateTransportWarnings[0].seqBefore,7);assert.throws(()=>recovered.reader.verify());recovered.reader.parse('{"mode":"hangar","loading":{"phase":"download"}}',7,null,'complete');recovered.reader.verify();assert.equal(recovered.report.stateTransportWarnings[0].recoveredBySequence,8);
 for(const raw of ['{"closed":}', '{"mismatch":]}', 'nullx', '{} garbage', '{"text":"}" garbage']){const fixture=make();fixture.reader.parse(raw,0,null,raw);assert.equal(fixture.report.probeErrors.length,1);assert.throws(()=>fixture.reader.verify())}
 const limit=make();for(let i=0;i<4;i++)limit.reader.parse('{"value":',0,null,'partial');assert.equal(limit.report.stateTransportWarnings.length,3);assert.equal(limit.report.probeErrors.length,1);assert.throws(()=>limit.reader.verify());
 const heap=make();heap.report.probeErrors.push({kind:'boundaries',error:'Unexpected end of JSON input'});assert.throws(()=>heap.reader.verify());
 const escape=make();escape.reader.parse('{"text":"brace } and \\" quote", "nested":[',1,null,'partial');assert.equal(escape.report.stateTransportWarnings.length,1);assert.throws(()=>escape.reader.verify());
 console.log('PASS: QA-only bounded transport recovery, unresolved/fourth/complete/mismatched/heap errors rejected, generated candidate syntax and drift rejection; no hardware launched');
}
module.exports={transport,missingContainerEnd,runnerSource,selfTest};
if(require.main===module){
 if(process.argv.includes('--self-test')){assert.deepEqual(process.argv.slice(2),['--self-test']);selfTest()}
 else{assert.deepEqual(process.argv.slice(2),[]);process.env.VOX_PREPARE_FILE='.tmp/outgame-cached-1792189057538/identity.json';const file=path.join(__dirname,'run-load-heap-boundary-short.cjs'),m=new Module(file,module);m.filename=file;m.paths=Module._nodeModulePaths(__dirname);m._compile(runnerSource(fs.readFileSync(file,'utf8')),file);m.exports.run().catch(error=>{console.error(error.stack);process.exitCode=1})}
}
