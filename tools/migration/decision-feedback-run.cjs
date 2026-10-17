'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {stages,imageSizes}=require('./decision-feedback-prepare.cjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function verify(rows){
 assert.deepEqual(rows.map(row=>row.stage),stages);
 for(const [index,row]of rows.entries()){
  assert.equal(row.fixture,true);assert(row.frames>=10);assert(row.viewport.every(Number.isFinite)&&row.design.every(Number.isFinite));assert(row.scale>0&&row.dpr>0);
  for(const name of ['machinist_idle','machinist_hero','company-emblem']){const image=row.images[name];assert(image.handle>0);assert.deepEqual([image.width,image.height],imageSizes[name],'Real decoded frozen image '+name);assert(image.path.startsWith('Intro/Images/'));}
  const q=[0,.5,1,1,1][index],decided=index>=3;
  assert.equal(row.owner.progress,q);assert.equal(row.owner.shot,decided?'decided':'decide');assert(row.owner.caption.length>0);
  assert(Math.abs(row.plan.cone-q*.9)<1e-9);assert.equal(row.plan.speed,decided?.75:0);assert(Math.abs(row.plan.brightness-(decided?1:.18+q*.8))<1e-9);
  assert(Math.abs(row.plan.rotation-(row.owner.time-20)*Math.PI*2/7)<1e-9,'Actual continuous rotation clock');
  if(!decided){const u=row.design[1]/100,hint=row.hold.instruction,label=row.hold.label;
   assert(Math.abs(hint.y-81.4*u)<1e-8&&Math.abs(hint.lineHeight-2.6*u)<1e-8&&Math.abs(hint.spacing-.364*u)<1e-8,'Source hold instruction bottom-anchored line box');
   assert(Math.abs(label.y-75.18*u)<1e-8&&Math.abs(label.size-2.42*u)<1e-8&&label.baseline,'Source SVG label baseline and scale');
  }else assert.equal(Object.keys(row.hold).length,0,'Decided state removes hold instruction');
 }
 assert(rows[4].plan.rotation>rows[3].plan.rotation,'Later decided frame advances');return true;
}
function verifySurface(surface){
 assert.equal(surface.loadingCount,0,'HTML startup overlay must be absent');
 assert.equal(surface.canvasCount,1);assert.equal(surface.width,1600);assert.equal(surface.height,900);
 assert(surface.topmost.every(id=>id==='canvas'),'Actual game canvas must be topmost at center and quadrants');
}
function verifyRendered(rows){
 assert.equal(rows.length,5);
 for(const row of rows){verifySurface(row.surface);assert.match(row.pngSha256,/^[a-f0-9]{64}$/);}
 for(const [a,b]of [[0,1],[1,2],[3,4]])assert.notEqual(rows[a].pngSha256,rows[b].pngSha256,'Distinct rendered decision stages '+a+'/'+b);
}
async function sourceHoldLayout(page,base,source,op){
 assert.equal(source.commit,'b276064942ae09c0227ec28d4cfda1d5ff006455');
 const url=base+'/__decision_source_hold_layout';
 const css=['style.css','new-ui-tokens.css','intro.css'].map(name=>'<link rel="stylesheet" href="'+base+'/baseline/shared/css/'+name+'">').join('');
 const html='<!doctype html><meta charset="utf-8">'+css+'<div id="intro"><div class="ly in-decide on"><div class="hold">'+source.html+'</div></div></div>';
 await op('source DOM fixture route',()=>page.route(url,route=>route.fulfill({status:200,contentType:'text/html',body:html})));
 const layouts=[];
 try{
  await op('frozen source DOM',()=>page.goto(url,{waitUntil:'networkidle',timeout:15000}));
  await op('source DOM font readiness',()=>page.evaluate(async()=>{await document.fonts.load('400 24px "VoxIndustrial"','按住');await document.fonts.ready;if(!document.fonts.check('400 24px "VoxIndustrial"','按住'))throw Error('Source hold font not loaded');}));
  for(const width of [1600,1200,2000]){
   await op('source DOM viewport '+width,()=>page.setViewportSize({width,height:900}));
   const row=await op('source DOM geometry '+width,()=>page.evaluate(()=>{
    const box=selector=>{const r=document.querySelector(selector).getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,bottom:r.bottom}};
    const style=getComputedStyle(document.querySelector('.hold .k')),svg=box('.hold svg'),circle=document.querySelector('.hold circle'),text=document.querySelector('.hold text');
    return {viewport:[innerWidth,innerHeight],hold:box('.hold'),svg,hint:box('.hold .k'),font:style.fontFamily,fontSize:parseFloat(style.fontSize),lineHeight:parseFloat(style.lineHeight),spacing:parseFloat(style.letterSpacing),
     circle:{x:svg.x+Number(circle.getAttribute('cx'))/100*svg.width,y:svg.y+Number(circle.getAttribute('cy'))/100*svg.height,r:Number(circle.getAttribute('r'))/100*svg.width},
     label:{baseline:svg.y+Number(text.getAttribute('y'))/100*svg.height,size:Number(text.getAttribute('font-size'))/100*svg.height}};
   }));
   const u=9,near=(a,b)=>assert(Math.abs(a-b)<.05,'Source DOM geometry '+a+' != '+b);
   near(row.hold.bottom,84*u);near(row.svg.width,11*u);near(row.svg.height,11*u);near(row.circle.y,74.3*u);near(row.circle.r,4.84*u);
   near(row.hint.y,81.4*u);near(row.hint.height,2.6*u);near(row.fontSize,2.6*u);near(row.lineHeight,2.6*u);near(row.spacing,.364*u);near(row.label.baseline,75.18*u);near(row.label.size,2.42*u);
   layouts.push(row);
  }
 }finally{await op('source DOM route cleanup',()=>page.unroute(url));await op('target viewport',()=>page.setViewportSize({width:1600,height:900}));}
 return layouts;
}
async function run(base,out){
 assert.match(base,/^http:\/\/127\.0\.0\.1:\d+$/);assert(!fs.existsSync(out),'Preserve prior fixture evidence');fs.mkdirSync(out,{recursive:true});
 const get=async route=>{const response=await fetch(base+route,{signal:AbortSignal.timeout(20000)});assert.equal(response.status,200,route);return Buffer.from(await response.arrayBuffer())};
 const identity=JSON.parse(await get('/identity.json'));assert(identity.decisionFeedback?.isolated&&identity.g1WebCpu?.isolated&&!identity.qa&&!identity.perfMonitor);
 assert.deepEqual(identity.decisionFeedback.stages,stages);
 assert.deepEqual(identity.decisionFeedback.imageSizes,imageSizes);
 for(const [name,hash]of Object.entries(identity.decisionFeedback.sourceHold.files))assert.equal(sha(await get('/baseline/'+name)),hash,'Actual HTTP frozen source '+name);
 const manifest=JSON.parse(await get('/game-dist/'+path.relative(path.join(identity.source_directory,'dist'),identity.manifest_path).replaceAll('\\','/')));
 const expected={'main.lua':identity.g1WebCpu.entrySha256,...identity.decisionFeedback.modules,...identity.decisionFeedback.resources},httpHashes={},payloads={};
 for(const [name,hash]of Object.entries(expected)){
  const entry=manifest.files.find(row=>row.fs_path===name);assert(entry,'Packaged '+name);
  const bytes=await get('/game-dist/assets/'+entry.uuid+'-'+entry.hash+entry.ext);httpHashes[name]=sha(bytes);assert.equal(httpHashes[name],hash,'Actual HTTP '+name);payloads[name]=bytes;
 }
 const data=JSON.parse(payloads['Intro/Intro.json']);
 for(const [name,size]of Object.entries(imageSizes)){const bytes=payloads[data.images[name]];assert(bytes);assert.equal(bytes.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.deepEqual([bytes.readUInt32BE(16),bytes.readUInt32BE(20)],size,'HTTP frozen PNG dimensions '+name);}
 const report={status:'RUNNING',identity,httpHashes,startedAt:new Date().toISOString(),errors:[],httpErrors:[],snapshots:[],
  boundary:'Actual frozen production UI module with fixture clocks. Pixel existence is not source screenshot equivalence, natural playback, audio continuity or sustained performance acceptance.'};
 const persist=()=>fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');persist();
 let browser,page,server,done=null,capture=Promise.resolve(),failure=null,totalTimer;
 const {createRuntimeWatchdog,isRuntimeFatal}=require('./salvage-runtime-watchdog.cjs');
 const watchdog=createRuntimeWatchdog({onFatal:event=>{failure=Error(JSON.stringify(event));report.fatal=event;persist();},operationTimeoutMs:15000});
 const op=(label,work,timeout)=>watchdog.operation(label,work,timeout);
 try{
  totalTimer=setTimeout(()=>watchdog.fail('decision-fixture-deadline','180s total deadline'),180000);
  const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
  server=await op('owned launch',()=>chromium.launchServer({headless:true,channel:'chrome',args:['--use-angle=d3d11']}),30000);
  browser=await op('owned connect',()=>chromium.connect(server.wsEndpoint()));page=await op('new page',()=>browser.newPage({viewport:{width:1600,height:900}}));
  page.on('console',message=>{
   const line=message.text();fs.appendFileSync(path.join(out,'runtime.log'),line+'\n');
   if(message.type()==='error'||/ERROR:|Aborted\(|stack traceback|Shader compilation failed|Failed to create bgfx/i.test(line)){report.errors.push(line);persist();}
   if(isRuntimeFatal(line))watchdog.fail('console',line);
   const prefix='DECISION_FEEDBACK_SNAPSHOT ',at=line.indexOf(prefix);
   if(at>=0)capture=capture.then(async()=>{
    const row=JSON.parse(line.slice(at+prefix.length));assert.equal(row.stage,stages[report.snapshots.length],'No duplicate or out-of-order ACK');
    assert.equal(row.owner.caption,data.caps[row.owner.shot==='decide'?'n06':'n07'],'Frozen source caption unchanged');
    const surface=await op('fixture canvas reveal '+row.stage,()=>page.evaluate(()=>{
     const loading=document.querySelector('#loading'),removedAfterRealRender=Boolean(loading);if(loading)loading.remove();
     const canvas=document.querySelector('#canvas'),rect=canvas.getBoundingClientRect();
     return {removedAfterRealRender,loadingCount:document.querySelectorAll('#loading').length,canvasCount:document.querySelectorAll('#canvas').length,
      width:rect.width,height:rect.height,topmost:[[.5,.5],[.25,.25],[.75,.25],[.25,.75],[.75,.75]].map(([x,y])=>document.elementFromPoint(innerWidth*x,innerHeight*y)?.id)};
    }));verifySurface(surface);
    const file=row.stage+'.png',png=await op('screenshot '+row.stage,()=>page.locator('#canvas').screenshot({path:path.join(out,file),timeout:10000}));
    const pixels=await op('pixel validation '+row.stage,()=>page.evaluate(async base64=>{
     const image=new Image();image.src='data:image/png;base64,'+base64;await image.decode();const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;
     const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0);const bytes=ctx.getImageData(0,0,image.width,image.height).data;
     let nonDark=0,colored=0,center=0,periphery=0;for(let y=0;y<image.height;y++)for(let x=0;x<image.width;x++){
      const i=(y*image.width+x)*4,hi=Math.max(bytes[i],bytes[i+1],bytes[i+2]),lo=Math.min(bytes[i],bytes[i+1],bytes[i+2]);
      if(hi>24){nonDark++;if(x>image.width*.3&&x<image.width*.7&&y<image.height*.8)center++;else periphery++;}if(hi>24&&hi-lo>12)colored++;
     }return {width:image.width,height:image.height,nonDark,colored,center,periphery};
    },png.toString('base64')));
    assert.equal(pixels.width,1600);assert.equal(pixels.height,900);assert(pixels.nonDark>1000&&pixels.center>100&&pixels.colored>100,'Real artwork and colored layers must be nonblank');
    report.snapshots.push({...row,file,pixels,surface,pngSha256:sha(png)});persist();await op('ACK '+row.stage,()=>page.keyboard.press('F8'));
   }).catch(error=>{report.errors.push(error.stack);failure=error;persist();});
   const final='DECISION_FEEDBACK_DONE ',end=line.indexOf(final);if(end>=0)try{assert.equal(done,null);done=JSON.parse(line.slice(end+final.length));}catch(error){failure=error;}
  });
  page.on('pageerror',error=>watchdog.fail('pageerror',error.stack||error.message));page.on('crash',()=>watchdog.fail('crash','Owned decision page crashed'));
  page.on('requestfailed',request=>{report.httpErrors.push({url:request.url(),failure:request.failure()});persist();});
  page.on('response',response=>{if(response.status()>=400){report.httpErrors.push({url:response.url(),status:response.status()});persist();}});
  report.sourceHoldLayouts=await sourceHoldLayout(page,base,identity.decisionFeedback.sourceHold,op);persist();
  await op('navigate isolated UI fixture',()=>page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1&-skip_login',{waitUntil:'domcontentloaded',timeout:30000}),35000);
  await op('focus owned fixture',()=>page.bringToFront());
  while(done===null){watchdog.throwIfFatal();if(failure)throw failure;assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0,'HTTP failures');await new Promise(resolve=>setTimeout(resolve,100));}
  await capture;assert.equal(done.status,'PASS',done.error);assert.equal(done.released,true);assert.equal(done.stages,5);verify(report.snapshots);verifyRendered(report.snapshots);
  const sourceLayout=report.sourceHoldLayouts.find(row=>row.viewport[0]===1600);
  for(const row of report.snapshots.slice(0,3)){const scale=900/row.design[1];assert(Math.abs(row.hold.instruction.y*scale-sourceLayout.hint.y)<.05,'Actual Lua hint aligns with frozen source DOM');assert(Math.abs(row.hold.label.y*scale-sourceLayout.label.baseline)<.05,'Actual Lua label baseline aligns with frozen source SVG');}
  assert.equal(report.errors.length,0,report.errors[0]);assert.equal(report.httpErrors.length,0);assert.deepEqual(JSON.parse(await get('/identity.json')),identity,'Service drift');
  report.status='PASS';report.result=done;
 }catch(error){report.status='FAIL';report.failure=error.stack;}
 finally{clearTimeout(totalTimer);report.shutdown=await require('./run-auto-gc-aba.cjs').closeOwnedBrowser(page,browser,server);if(report.shutdown.status!=='CLOSED')report.status='FAIL';report.finishedAt=new Date().toISOString();persist();}
 console.log(JSON.stringify({status:report.status,out,stages:report.snapshots.length,shutdown:report.shutdown.status,failure:report.failure}));
 if(report.status!=='PASS')throw Error(report.failure||'Owned browser not closed');return report;
}
function selfTest(){
 const rows=stages.map((stage,index)=>{const q=[0,.5,1,1,1][index],decided=index>=3,time=[21.2,21.85,22.5,23.2,24][index];return {stage,fixture:true,frames:10,viewport:[1920,1080],design:[1920,1080],scale:1,dpr:1,
  images:Object.fromEntries(['machinist_idle','machinist_hero','company-emblem'].map(name=>[name,{handle:1,width:imageSizes[name][0],height:imageSizes[name][1],path:'Intro/Images/'+name+'.png'}])),
  hold:decided?{}:{instruction:{y:81.4*10.8,lineHeight:2.6*10.8,spacing:.364*10.8},label:{y:75.18*10.8,size:2.42*10.8,baseline:true}},
  owner:{progress:q,shot:decided?'decided':'decide',caption:'frozen caption',time},plan:{cone:q*.9,speed:decided?.75:0,brightness:decided?1:.18+q*.8,rotation:(time-20)*Math.PI*2/7}};});
 verify(rows);let rejected=0;for(const mutate of [r=>r[1].plan.cone=0,r=>r[3].plan.speed=0,r=>r[4].images.machinist_hero.handle=0,r=>r[0].frames=0,r=>r[4].plan.rotation=0,r=>r[0].images.machinist_idle={handle:1,width:16,height:16,path:'Intro/Images/machinist_idle.png'},r=>r[1].hold.instruction.y=84*10.8,r=>r[1].hold.label.baseline=false]){const bad=structuredClone(rows);mutate(bad);assert.throws(()=>verify(bad));rejected++;}
 const surface={loadingCount:0,canvasCount:1,width:1600,height:900,topmost:Array(5).fill('canvas')};
 const rendered=rows.map((row,index)=>({...row,surface,pngSha256:sha(Buffer.from(String(index)))}));verifyRendered(rendered);
 for(const mutate of [r=>r[0].surface={...surface,loadingCount:1},r=>r[1].surface={...surface,topmost:['loading']},r=>r[1].pngSha256=r[0].pngSha256,r=>r[4].pngSha256=r[3].pngSha256]){
  const bad=structuredClone(rendered);mutate(bad);assert.throws(()=>verifyRendered(bad));rejected++;
 }
 console.log(JSON.stringify({status:'READY_NOT_RUN',stages:5,rejectedMutations:rejected,hardware:false}));
}
module.exports={run,verify,verifySurface,verifyRendered,sourceHoldLayout,selfTest};
if(require.main===module){if(process.argv.includes('--self-test'))selfTest();else run(process.argv[2],path.resolve(process.argv[3])).catch(error=>{console.error(error.stack);process.exitCode=1;});}
