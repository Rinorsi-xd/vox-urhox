'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const stages=['before','hit','decayed','explosion-hit','culled','cull-return','shielded'];
function verifySurface(surface){
 assert(surface.loadingAbsent&&surface.canvasOnTop.length===5&&surface.canvasOnTop.every(Boolean),'Fixture shell must expose canvas');
 assert.deepEqual(surface.canvasRect,[0,0,960,540],'Canvas fills fixture viewport');
}
function verify(rows){
 assert.deepEqual(rows.map(r=>r.stage),stages);
 for(const row of rows){assert.equal(row.fixture,true);for(const team of ['blue','red']){
  const r=row.reactors[team];assert(Number.isInteger(r.vertexCount)&&r.vertexCount>0);assert(Number.isInteger(r.firstVertexColor));
  assert(r.position.length===3&&r.position.every(Number.isFinite));assert(r.rgba.length===4&&r.rgba.every(v=>Number.isFinite(v)&&v>=0&&v<=1));
  assert(r.flash>=0&&r.flash<=1);assert.equal(row.reactors.blue.flash,0,'Other reactor not hit');
 }}
 const [before,hit,decayed,explosion,culled,returned,shielded]=rows;
 assert(hit.pixelCheck.white>before.pixelCheck.white+20&&hit.pixelCheck.white>decayed.pixelCheck.white+20,'Actual canvas hit becomes whiter than idle/decayed');
 assert(explosion.pixelCheck.white>before.pixelCheck.white+20,'Actual canvas explosion becomes white');
 assert.equal(before.reactors.red.flash,0);assert.equal(hit.reactors.red.flash,1);assert.equal(decayed.reactors.red.flash,0);
 assert.equal(explosion.reactors.red.flash,1);assert(returned.reactors.red.flash>0&&returned.reactors.red.flash<1);
 for(const row of [hit,explosion]){
  assert(row.reactors.red.rgba.slice(0,3).every(v=>v>.99),'Actual uploaded white color');
  assert.notEqual(row.reactors.red.position[0],-6,'Actual horizontal jitter');
  assert(Math.abs(row.reactors.red.position[0]+6)<=.15);
  assert.equal(row.reactors.blue.firstVertexColor,before.reactors.blue.firstVertexColor,'Other reactor retains color');
 }
 assert.equal(decayed.reactors.red.position[0],-6);assert(decayed.reactors.red.rgba[2]<.5,'White flash ended');
 assert(hit.score.red<before.score.red&&hit.score.blue>before.score.blue,'Actual ray theft');
 assert(explosion.score.red<hit.score.red&&explosion.score.blue>hit.score.blue,'Actual explosion theft');
 assert.equal(culled.reactors.red.enabled,false);assert.equal(culled.reactors.blue.enabled,false);
 assert.equal(culled.reactors.red.culled,true);assert.equal(returned.reactors.red.enabled,true);assert.equal(returned.reactors.red.culled,false);
 assert(returned.reactors.red.rgba[2]>.5,'Returning flash read back from actual geometry');
 assert.equal(shielded.reactors.red.flash,0);assert.equal(shielded.shield.red,true);assert.equal(shielded.score.red,explosion.score.red);
 assert.equal(shielded.reactors.red.position[0],-6);return true;
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Preserve prior result');fs.mkdirSync(out,{recursive:true});
 const get=async url=>{const r=await fetch(url);assert(r.ok,url+' '+r.status);return Buffer.from(await r.arrayBuffer())};
 const identity=JSON.parse(await get(base+'/identity.json'));assert(identity.reactorFeedback?.isolated&&identity.g1WebCpu?.isolated&&!identity.qa&&!identity.perfMonitor);
 assert.deepEqual(identity.reactorFeedback.stages,stages);
 const manifest=JSON.parse(await get(base+'/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')));
 const expected={'main.lua':identity.g1WebCpu.entrySha256,...identity.reactorFeedback.modules};
 const httpHashes={};for(const [name,hash]of Object.entries(expected)){
  const entry=manifest.files.find(r=>r.fs_path===name);assert(entry,'Packaged '+name);
  const bytes=await get(base+'/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);httpHashes[name]=sha(bytes);assert.equal(httpHashes[name],hash,'Actual HTTP '+name);
 }
 const report={status:'RUNNING',identity,httpHashes,startedAt:new Date().toISOString(),errors:[],httpErrors:[],snapshots:[]};
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');persist();
 let browser,done=null,capture=Promise.resolve();
 try{
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
  const page=await browser.newPage({viewport:{width:960,height:540}});
  page.on('console',message=>{
   const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(message.type()==='error'||/ERROR:|Aborted\(|stack traceback|Shader compilation failed|Failed to create bgfx/i.test(line))report.errors.push(line);
   const prefix='REACTOR_FEEDBACK_SNAPSHOT ',at=line.indexOf(prefix);
   if(at>=0)capture=capture.then(async()=>{
    const row=JSON.parse(line.slice(at+prefix.length));assert.equal(row.stage,stages[report.snapshots.length],'No duplicate/out-of-order ACK');
    assert(Number.isInteger(row.updateCallbacks)&&row.updateCallbacks>=60,'First native readback follows fixture engine updates');
    const shellAudit=await page.evaluate(remove=>{
     const loading=document.querySelector('#loading');const removed=!!loading&&remove;
     if(removed)loading.remove();
     const canvas=document.querySelector('#canvas');const rect=canvas?.getBoundingClientRect();
     const points=[[.5,.5],[.25,.25],[.75,.25],[.25,.75],[.75,.75]];
     return {removedAfterNativeSnapshot:removed,loadingAbsent:!document.querySelector('#loading'),
      viewport:[innerWidth,innerHeight],canvasRect:rect&&[rect.x,rect.y,rect.width,rect.height],
      canvasOnTop:points.map(([x,y])=>document.elementFromPoint(innerWidth*x,innerHeight*y)===canvas)};
    },row.stage==='before');
    verifySurface(shellAudit);
    const file=row.stage+'.png';const png=await page.locator('#canvas').screenshot({path:path.join(out,file),timeout:15000});
    const pixelCheck=await page.evaluate(async bytes=>{
     const img=new Image();img.src='data:image/png;base64,'+bytes;await img.decode();
     const canvas=document.createElement('canvas');canvas.width=img.width;canvas.height=img.height;
     const ctx=canvas.getContext('2d');ctx.drawImage(img,0,0);const data=ctx.getImageData(0,0,img.width,img.height).data;
     let nonDark=0,colored=0,white=0;for(let i=0;i<data.length;i+=4){const hi=Math.max(data[i],data[i+1],data[i+2]),lo=Math.min(data[i],data[i+1],data[i+2]);if(hi>24)nonDark++;if(hi>24&&hi-lo>12)colored++;if(lo>180)white++}
     return {width:img.width,height:img.height,nonDark,colored,white};
    },png.toString('base64'));
    assert.equal(pixelCheck.width,960);assert.equal(pixelCheck.height,540);
    if(row.stage!=='culled')assert(pixelCheck.nonDark>100&&pixelCheck.colored>40,'Rendered reactor pixels must be nonblank');
    report.snapshots.push({...row,file,pixelCheck,shellAudit,screenshotSha256:sha(png)});persist();await page.keyboard.press('F8');
   }).catch(error=>report.errors.push('Capture: '+error.stack));
   const final='REACTOR_FEEDBACK_DONE ',end=line.indexOf(final);
   if(end>=0)try{assert.equal(done,null,'Duplicate DONE');done=JSON.parse(line.slice(end+final.length))}catch(error){report.errors.push(error.message)}
  });
  page.on('pageerror',error=>report.errors.push(error.message));page.on('crash',()=>report.errors.push('Renderer crashed'));
  page.on('requestfailed',request=>report.httpErrors.push({url:request.url(),failure:request.failure()}));
  page.on('response',response=>{if(response.status()>=400)report.httpErrors.push({url:response.url(),status:response.status()})});
  await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000});
  const deadline=Date.now()+180000;
  while(done===null){assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,'HTTP failures');assert(Date.now()<deadline,'Reactor fixture timeout');await new Promise(resolve=>setTimeout(resolve,100))}
  await capture;assert.equal(done.status,'PASS',done.error);assert.equal(done.released,true);assert.equal(done.stages,7);
  assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0);verify(report.snapshots);
  assert.deepEqual(JSON.parse(await get(base+'/identity.json')),identity,'Service identity drift');report.result=done;report.status='PASS';
 }catch(error){report.status='FAIL';report.failure=error.stack;throw error}
 finally{
  if(browser)try{await Promise.race([browser.close(),new Promise((_,reject)=>setTimeout(()=>reject(Error('Close timeout')),5000))]);report.shutdown='CLOSED'}catch(error){report.shutdown='UNCONFIRMED';report.closeError=error.message}
  report.finishedAt=new Date().toISOString();persist();console.log(JSON.stringify({status:report.status,shutdown:report.shutdown,out,failure:report.failure}));
 }
 return report;
}
function selfTest(){
 const row=stage=>({stage,fixture:true,pixelCheck:{white:0},score:{blue:50,red:50},shield:{blue:true,red:false},reactors:{}});
 const rows=stages.map(row);
 for(const row of rows)for(const team of ['blue','red'])row.reactors[team]={vertexCount:552,firstVertexColor:team==='blue'?1:2,position:[team==='blue'?6:-6,0,0],rgba:[1,.2,.1,.95],flash:0,enabled:true,culled:false};
 for(const i of [1,3]){const r=rows[i].reactors.red;r.flash=1;r.rgba=[1,1,1,.95];r.position[0]= -6.1;r.firstVertexColor=3;rows[i].pixelCheck.white=200}
 for(let i=1;i<rows.length;i++)rows[i].score={blue:i<3?52:53.2,red:i<3?48:46.8};
 for(const team of ['blue','red']){rows[4].reactors[team].enabled=false;rows[4].reactors[team].culled=true}
 rows[5].reactors.red.flash=.7;rows[5].reactors.red.rgba=[1,.8,.7,.95];rows[6].shield.red=true;
 verify(rows);let rejected=0;
 for(const mutate of [r=>r[1].reactors.red.flash=0,r=>r[1].reactors.red.rgba=[1,.2,.1,.95],r=>r[5].reactors.red.enabled=false,r=>r[6].score.red=0,r=>r[1].reactors.blue.firstVertexColor=5,r=>r.forEach(s=>s.pixelCheck.white=300)]){
  const bad=structuredClone(rows);mutate(bad);assert.throws(()=>verify(bad));rejected++;
 }
 const surface={loadingAbsent:true,canvasOnTop:[true,true,true,true,true],canvasRect:[0,0,960,540]};verifySurface(surface);
 for(const mutate of [s=>s.loadingAbsent=false,s=>s.canvasOnTop[1]=false,s=>s.canvasRect[2]=959]){
  const bad=structuredClone(surface);mutate(bad);assert.throws(()=>verifySurface(bad));rejected++;
 }
 console.log(JSON.stringify({status:'READY_NOT_RUN',checks:'Stage/readback positive fixture',rejectedMutations:rejected,hardware:false}));
}
module.exports={run,verify,verifySurface,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3])).catch(error=>{console.error(error.stack);process.exitCode=1})}
