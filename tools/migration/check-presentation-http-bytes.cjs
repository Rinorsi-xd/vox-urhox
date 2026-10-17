// Execute the actual HTTP handler with an in-memory socket, never listen or run a game.
'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {createRequire}=require('node:module'),{Writable}=require('node:stream'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),snapshot=path.join(root,'.tmp/outgame-cached-1792183721377');
const prepared=JSON.parse(fs.readFileSync(path.join(snapshot,'identity.json')));
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const main=manifest.files.find(file=>file.fs_path==='main.lua'),payload=main.uuid+'-'+main.hash+main.ext;
const packed=fs.readFileSync(path.join(snapshot,'dist/assets',payload));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const build=require('./build-frame-pipeline-probe.cjs');
async function capture(flags){
 let handler;
 const localRequire=createRequire(path.join(__dirname,'serve-outgame.cjs'));
 const mockedRequire=name=>name==='node:http'?{createServer(callback){handler=callback;return {listen(){},close(){}}}}:localRequire(name);
 const sandbox={require:mockedRequire,module:{exports:{}},exports:{},__dirname,__filename:path.join(__dirname,'serve-outgame.cjs'),
  Buffer,URL,console:{log(){},error(){}},process:{argv:['node','serve-outgame.cjs',...flags],env:{VOX_PREPARE_FILE:path.join(snapshot,'identity.json'),VOX_PREVIEW_PORT:'49998'},pid:process.pid,on(){}}};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'serve-outgame.cjs'),'utf8'),sandbox,{filename:'serve-outgame.cjs'});
 sandbox.module.exports.startPreviewServer();assert.equal(typeof handler,'function');
 async function request(url){
  const chunks=[];let code=200;
  const response=new Writable({write(chunk,encoding,done){chunks.push(Buffer.from(chunk));done()}});
  response.setHeader=()=>{};response.writeHead=value=>{code=value;return response};
  const finished=new Promise((resolve,reject)=>{response.on('finish',resolve);response.on('error',reject)});
  handler({url,headers:{}},response);await finished;assert.equal(code,200,url);return Buffer.concat(chunks);
 }
 const identity=JSON.parse(await request('/identity.json'));
 const servedMain=await request('/game-dist/assets/'+payload);
 const servedManifest=JSON.parse(await request('/game-dist/1.0.0/'+path.basename(prepared.manifest_path)));
 return {identity,servedMain,servedManifest};
}
async function mainTest(){
 const results=[];
 for(const mode of ['ordinary','qa','fixed','presentation','beforeStep','vehicle']){
  const vehicle=mode==='vehicle',detailed=mode==='beforeStep'||vehicle,presentation=mode==='presentation'||detailed;
  const flags=mode==='ordinary'?[]:['--qa','--monitor-disabled'];
  if(mode==='fixed'||presentation)flags.push('--profile-frame-pipeline','--profile-fixed-step-pipeline');
  if(presentation)flags.push('--profile-presentation-pipeline');
  if(detailed)flags.push('--profile-before-step-pipeline');
  if(vehicle)flags.push('--profile-vehicle-pipeline');
  const actual=await capture(flags),qa=mode!=='ordinary';
  let suffix=qa?fs.readFileSync(path.join(__dirname,'qa-frame-wall-observer.lua'),'utf8')+'\n'+fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8')+'\n'+fs.readFileSync(path.join(__dirname,'monitor-disabled-observer.lua'),'utf8'):'';
  if(mode==='fixed'||presentation)suffix+='\n'+build.buildFramePipelineProbe(prepared,{fixedSteps:true,presentation,beforeStep:detailed,vehicle})+'\n'+fs.readFileSync(path.join(__dirname,'qa-frame-pipeline-control.lua'),'utf8');
  const expected=qa?Buffer.concat([packed,Buffer.from('\n'+suffix)]):packed;
  assert.ok(actual.servedMain.equals(expected),'Actual handler exact main bytes '+mode);
  assert.equal(actual.identity.probeSha256,qa?sha(suffix):null);
  assert.equal(actual.identity.presentationPipelineProfile===true,presentation);
  assert.equal(actual.identity.beforeStepPipelineProfile===true,detailed);
  assert.equal(actual.identity.vehiclePipelineProfile===true,vehicle);
  const expectedManifest=structuredClone(manifest);if(qa)expectedManifest.files.find(file=>file.fs_path==='main.lua').size=expected.length;
  assert.deepEqual(actual.servedManifest,expectedManifest,'Only main.size changes');
  const bad=Buffer.from(actual.servedMain);bad[bad.length-1]^=1;assert.ok(!bad.equals(expected),'Altered suffix negative control');
  results.push({mode,mainBytes:expected.length,mainSha256:sha(expected),probeSha256:actual.identity.probeSha256,exactBytes:true});
 }
 console.log(JSON.stringify({result:'PASS',observations:results,negativeControls:results.length,boundary:'Actual serve-outgame HTTP request handler executed with in-memory Writable responses. No listening socket, browser, Runtime, rendered view, performance or device test. Root must still audit the live dedicated service bytes.'},null,2));
}
if(require.main===module)mainTest().catch(error=>{console.error(error);process.exitCode=1});
module.exports={mainTest};
