'use strict';
// Public touch input against the existing immutable package; no gameplay injection.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),evidence=path.join(root,'docs/migration/evidence');
const selection=process.env.VOX_MOBILE_HOTBAR_SNAPSHOT||process.env.VOX_PREPARE_FILE||'.tmp/outgame-cached-1792183721377/identity.json';
const selectedPath=path.resolve(root,selection),prepareFile=fs.statSync(selectedPath).isDirectory()?path.join(selectedPath,'identity.json'):selectedPath;
const baseline='b276064942ae09c0227ec28d4cfda1d5ff006455';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'20-9',width:840,height:378,dpr:3},{name:'narrow',width:640,height:320,dpr:3}];
async function bounded(promise,label,ms=5000){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label)),ms)})])}finally{clearTimeout(timer)}}
function offline(){
 const prepared=JSON.parse(fs.readFileSync(prepareFile,'utf8').replace(/^\uFEFF/,''));
 assert.equal(prepared.ok,true);const frozen=path.resolve(prepared.source_directory),manifestName=path.basename(prepared.manifest_path);
 const source=JSON.parse(fs.readFileSync(path.join(evidence,'source-mobile-editor-20261017.json'),'utf8'));
 const reference=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
 assert.equal(source.baseline,baseline);assert.equal(reference.commit,baseline);
 assert.equal(prepared.identity.sourceCommit,baseline);assert.match(manifestName,/^manifest-[0-9a-f]+\.json$/);
 assert.match(prepared.identity.scriptFingerprint,/^[0-9a-f]{64}$/);
 assert.equal(sha(JSON.stringify(Object.entries(prepared.identity.scripts).sort())),prepared.identity.scriptFingerprint,'Recorded script fingerprint');
 const moduleNames=Object.keys(prepared.identity.scripts).sort();
 const packagedModules=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8')).files
  .filter(file=>file.fs_path.endsWith('.lua')).map(file=>file.fs_path).sort();
 assert(moduleNames.length>=547,'Complete migrated module inventory');
 assert.deepEqual(moduleNames,packagedModules,'Exact packaged Lua module list');
 for(const [file,digest]of Object.entries(prepared.identity.scripts)){
  assert.equal(sha(fs.readFileSync(path.join(root,'scripts',file))),digest,'Production drift '+file);
  assert.equal(sha(fs.readFileSync(path.join(frozen,'scripts',file))),digest,'Frozen drift '+file);
 }
 for(const [file,digest]of Object.entries(source.sourceHashes))assert.equal(reference.files[file].sha256,digest,'Source capture '+file);
 for(const test of cases){const view=source.layouts.find(view=>view.width===test.width&&view.height===test.height);assert.ok(view);
  assert.equal(view.states.tap.filter(item=>item.action==='me-slot').length,10);
 }
 return {prepared,source,frozen,manifestName};
}
async function main(){
 const {prepared,source,frozen,manifestName}=offline();
 const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4531);
 const identity=await fetch(base+'/identity.json').then(response=>{assert.equal(response.status,200);return response.json()});
 assert.equal(identity.qa,true);assert.equal(identity.source_directory,prepared.source_directory);
 assert.equal(identity.servedManifest,manifestName);assert.deepEqual(identity.identity,prepared.identity);
 assert.equal(identity.homeRoute,false);assert.equal(identity.storyRoute,false);
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
 const actualManifest=await fetch(base+'/game-dist/1.0.0/'+manifestName).then(response=>{assert.equal(response.status,200);return response.json()});
 const mainFile=manifest.files.find(file=>file.fs_path==='main.lua');assert.ok(mainFile);
 const filename=mainFile.uuid+'-'+mainFile.hash+mainFile.ext;
 const rawMain=fs.readFileSync(path.join(frozen,'dist/assets',filename));
 const servedMain=Buffer.from(await fetch(base+'/game-dist/assets/'+filename).then(response=>{assert.equal(response.status,200);return response.arrayBuffer()}));
 assert.ok(servedMain.subarray(0,rawMain.length).equals(rawMain),'Exact frozen main prefix');
 assert.equal(servedMain[rawMain.length],10);assert.equal(sha(servedMain.subarray(rawMain.length+1)),identity.probeSha256,'Exact declared QA observer suffix');
 assert.equal(actualManifest.files.find(file=>file.fs_path==='main.lua').size,servedMain.length,'Actual manifest matches QA main size');
 const normalized=structuredClone(actualManifest);normalized.files.find(file=>file.fs_path==='main.lua').size=mainFile.size;assert.deepEqual(normalized,manifest,'Only declared QA main size changes');
 const out=path.join(evidence,'mobile-hotbar-'+manifestName.replace(/^manifest-|\.json$/g,'')+'-'+Date.now());fs.mkdirSync(out,{recursive:true});
 const report={result:'RUNNING',identity,sourceBaseline:baseline,sourceCaptureSha256:sha(fs.readFileSync(path.join(evidence,'source-mobile-editor-20261017.json'))),cases:[],out,
  boundary:'Real browser touch rendering and hotbar selection only. No mobile sustained performance, safe-area, cancellation or complete G2 claim.'};
 let browser,server,page,lastPage;
 try{
  server=await chromium.launchServer({headless:true,channel:'chrome',args:['--use-angle=d3d11']});browser=await chromium.connect(server.wsEndpoint());
  for(const test of cases){
   let state,sequence=0;const item={viewport:test,result:'RUNNING',checks:[],errors:[],parseErrors:[],httpErrors:[],samples:[]};report.cases.push(item);
   page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,hasTouch:true,isMobile:true});lastPage=page;
   page.on('console',message=>{const text=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),text+'\n');const offset=text.indexOf('OUTGAME_STATE ');
    if(offset>=0)try{state=JSON.parse(text.slice(offset+14));sequence++}catch(error){item.parseErrors.push({error:error.message,truncated:!text.trimEnd().endsWith('}')})}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed|\[LoadingFlow\] Failed/.test(text))item.errors.push(text);
   });
   page.on('pageerror',error=>item.errors.push(error.message));page.on('response',response=>{if(response.status()>=400)item.httpErrors.push({status:response.status(),url:response.url()})});
   const check=(value,label)=>{assert.ok(value,label);item.checks.push(label)};
   const healthy=()=>assert.equal(item.errors.length,0,item.errors.join('\n'));
   async function key(value){await page.keyboard.press(value);await sleep(160)}
   async function wait(predicate,label,timeout=180000){const started=Date.now();let next=0;while(!state||!predicate(state)){
    healthy();if(Date.now()-started>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
    if(Date.now()>next){next=Date.now()+900;await key('F8')}await sleep(80);
   }return state}
   async function dump(){const old=sequence;await key('F8');await wait(()=>sequence>old,'fresh snapshot',15000);return state}
   async function tap(rect){const canvas=await page.locator('canvas').boundingBox();assert.ok(canvas);const x=canvas.x+(rect[0]+rect[2]/2)/state.width*canvas.width,y=canvas.y+(rect[1]+rect[3]/2)/state.height*canvas.height;
    assert.ok(x>0&&x<test.width&&y>0&&y<test.height,'Tap is inside CSS viewport');await page.touchscreen.tap(x,y);await sleep(250);await dump();return {x,y};
   }
   async function shot(name){await dump();item.samples.push({name,sequence,state:structuredClone(state)});const bytes=await page.screenshot({path:path.join(out,test.name+'-'+name+'.png'),timeout:15000});
    check((await sharp(bytes).stats()).channels.some(channel=>channel.stdev>20),'Nonblank rendered '+name);
   }
   try{
    await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-vox-debug=1');
    await wait(state=>state.tab==='hangar'&&!state.loadingFlow?.active,'actionable hall');await key('e');
    await wait(state=>state.build&&state.touchControls?.editor&&!state.loadingFlow?.active,'public editor');await dump();
    check(state.touchControls.prefs.build==='tap','Default source tap mode');
    const reference=source.layouts.find(view=>view.width===test.width&&view.height===test.height).states.tap.filter(row=>row.action==='me-slot');
    const rects=state.touchControls.rects;
    check(Object.keys(rects).filter(key=>/^slot-\d+$/.test(key)).length===10,'Ten actual visible hotbar hit targets');
    item.rectangles=[];
    for(let index=1;index<=10;index++){
     const rect=rects['slot-'+index];assert.ok(rect,'Actual slot '+index);const css=[rect[0]/state.width*test.width,rect[1]/state.height*test.height,rect[2]/state.width*test.width,rect[3]/state.height*test.height];
     item.rectangles.push({index,actual:css,source:reference[index-1].rect});
     check(css.every((value,i)=>Math.abs(value-reference[index-1].rect[i])<=1),'Current H5 slot rectangle '+index);
     check(css[0]>=0&&css[1]>=0&&css[0]+css[2]<=test.width&&css[1]+css[3]<=test.height,'Fully visible slot '+index);
     if(index>1)check(css[0]>=item.rectangles[index-2].actual[0]+item.rectangles[index-2].actual[2]-.5,'No overlapping adjacent slots '+index);
    }
    await shot('editor');item.selections=[];
    for(const index of [9,10,1]){
     const parts=state.parts,before=state.buildInput.slot,point=await tap(state.touchControls.rects['slot-'+index]);
     item.selections.push({requested:index,before,actual:state.buildInput.slot,point,sequence});
     check(state.buildInput.slot===index,'Real touch selects hotbar '+index);
     check(state.parts===parts&&!state.inventory,'Hotbar selection preserves blueprint and keeps editor '+index);
     await shot('selected-'+index);
    }
    await tap(state.touchControls.rects['me-back']);await wait(state=>!state.build&&state.tab==='hangar'&&!state.loadingFlow?.active,'public hall return');
    check(item.httpErrors.length===0,'No HTTP failures');check(item.parseErrors.every(error=>error.truncated),'No malformed complete state');healthy();item.result='PASS';
   }catch(error){item.result='FAIL';item.failure=error.stack;item.lastState=state;await page.screenshot({path:path.join(out,test.name+'-failure.png'),timeout:10000}).catch(()=>{});throw error}
   finally{await bounded(page.close({runBeforeUnload:false}),'Page close timeout',3000);page=null;fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2))}
  }
  const finalIdentity=await fetch(base+'/identity.json').then(response=>response.json());assert.deepEqual(finalIdentity,identity);offline();report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1}
 finally{report.shutdown=await require('./run-auto-gc-aba.cjs').closeOwnedBrowser(page||lastPage,browser,server);report.finishedAt=new Date().toISOString();
  fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({result:report.result,out,shutdown:report.shutdown,failure:report.failure}));
 }
}
module.exports={offline};
if(require.main===module){if(process.argv.includes('--self-test')){const {prepared}=offline();console.log('PASS: '+Object.keys(prepared.identity.scripts).length+' production/frozen hashes and exact packaged module list, current b276 source identity and both ten-slot references; no browser launched')}else main().catch(error=>{console.error(error.stack);process.exitCode=1})}
