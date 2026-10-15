const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),port=Number(process.env.VOX_G0_PORT||4219),base='http://127.0.0.1:'+port;
const webglTiming=process.argv.includes('--webgl-timing');
const surfaceChecks=process.argv.includes('--surface-checks');
const out=path.join(root,'docs/migration/evidence/g0-profile',new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(out,{recursive:true});const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function summary(p){const nodes=new Map(p.nodes.map(n=>[n.id,n])),times=new Map();for(let i=0;i<(p.samples||[]).length;i++)times.set(p.samples[i],(times.get(p.samples[i])||0)+p.timeDeltas[i]);return [...times].map(([id,us])=>({ms:us/1000,...nodes.get(id).callFrame})).sort((a,b)=>b.ms-a.ms).slice(0,40);}
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
try{
 const gpu=await browser.newBrowserCDPSession(),gpuInfo=await gpu.send('SystemInfo.getInfo');fs.writeFileSync(path.join(out,'gpu.json'),JSON.stringify(gpuInfo.gpu));
 const identity=await fetch(base+'/identity.json').then(r=>r.json());fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity));
 const page=await browser.newPage({viewport:{width:1920,height:1080}}),cdp=await page.context().newCDPSession(page);let state;const logs=[],states=[];
 const requests=new Map();let networkPhase='boot';
 await cdp.send('Network.enable');
 cdp.on('Network.requestWillBeSent',e=>{
  const url=new URL(e.request.url);url.search='';url.hash='';
  requests.set(e.requestId,{id:e.requestId,url:url.href,phase:networkPhase,start:e.timestamp,wallStart:e.wallTime,type:e.type});
 });
 cdp.on('Network.responseReceived',e=>{const r=requests.get(e.requestId);if(r){r.response=e.timestamp;r.status=e.response.status;r.timing=e.response.timing;r.fromDiskCache=e.response.fromDiskCache;}});
 cdp.on('Network.loadingFinished',e=>{const r=requests.get(e.requestId);if(r){r.end=e.timestamp;r.encodedBytes=e.encodedDataLength;r.durationMs=(e.timestamp-r.start)*1000;}});
 cdp.on('Network.loadingFailed',e=>{const r=requests.get(e.requestId);if(r){r.end=e.timestamp;r.error=e.errorText;}});
 const saveNetwork=()=>fs.writeFileSync(path.join(out,'network.json'),JSON.stringify({identity:identity.servedManifest,requests:[...requests.values()]},null,2));
 page.on('close',()=>{saveNetwork();fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));fs.writeFileSync(path.join(out,'last-state.json'),JSON.stringify(state));});
 page.on('console',m=>{const line=m.text();logs.push(line);if(line.includes('OUTGAME_STATE '))try{state=JSON.parse(line.slice(line.indexOf('OUTGAME_STATE ')+14));states.push({at:Date.now(),state});}catch{}});
 await page.addInitScript(()=>{window.__voxG0Frames=[];let prev=0;function tick(now){if(prev)window.__voxG0Frames.push({at:now,ms:now-prev});prev=now;requestAnimationFrame(tick);}requestAnimationFrame(tick);});
 if(webglTiming)await page.addInitScript(()=>{
  const data=window.__voxG0WebGL={phase:'boot',methods:{},slow:[],shaders:[],programs:{},longTasks:[],limitation:'Instrumented JS API wall time includes synchronous driver wait. It is not GPU execution time or a native mutex owner trace.'};
  const shaders=new WeakMap(),programs=new WeakMap();let nextShader=0,nextProgram=0;
  try{new PerformanceObserver(list=>{for(const e of list.getEntries())data.longTasks.push({phase:data.phase,at:e.startTime,ms:e.duration});}).observe({type:'longtask',buffered:true});}catch{}
  const methods=['shaderSource','compileShader','attachShader','linkProgram','getShaderParameter','getProgramParameter','getShaderInfoLog','getProgramInfoLog','getUniformLocation','getActiveUniform','texImage2D','texSubImage2D','texImage3D','texSubImage3D','compressedTexImage2D','compressedTexSubImage2D','compressedTexImage3D','compressedTexSubImage3D','generateMipmap','bufferData','bufferSubData','readPixels','finish','clientWaitSync','getError'];
  const wrapped=new Set();
  for(const ctor of [window.WebGLRenderingContext,window.WebGL2RenderingContext]){
   if(!ctor)continue;
   for(const method of methods){
    if(!Object.hasOwn(ctor.prototype,method))continue;
    const original=ctor.prototype[method];if(typeof original!=='function'||wrapped.has(original))continue;
    const wrapper=function(...args){
     let shader,program;
     if(method!=='attachShader'&&/Shader|shaderSource/.test(method)&&args[0]){
      shader=shaders.get(args[0]);if(!shader){shader=++nextShader;shaders.set(args[0],shader);}
      if(method==='shaderSource')data.shaders.push({id:shader,phase:data.phase,source:args[1]});
     }
     if((method==='attachShader'||/Program/.test(method))&&args[0]){program=programs.get(args[0]);if(!program){program=++nextProgram;programs.set(args[0],program);}}
     if(method==='attachShader'){shader=shaders.get(args[1]);(data.programs[program]??=[]).push(shader);}
     const start=performance.now();
     try{return Reflect.apply(original,this,args);}finally{
      const ms=performance.now()-start,key=data.phase+':'+method,entry=data.methods[key]??={calls:0,totalMs:0,maxMs:0};
      entry.calls++;entry.totalMs+=ms;entry.maxMs=Math.max(entry.maxMs,ms);
      if(ms>=20&&data.slow.length<10000)data.slow.push({phase:data.phase,method,at:start,ms,shader,program,pname:/Parameter/.test(method)?args[1]:undefined});
     }
    };
    wrapped.add(wrapper);ctor.prototype[method]=wrapper;
   }
  }
 });
 const captured=new Set();
 async function wait(pred,label,timeout=300000){const start=Date.now();let next=start+1000;while(!state||!pred(state)){const error=logs.find(l=>/Execute Lua function failed|Aborted\(/.test(l));if(error){fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));throw Error(error);}if(Date.now()-start>timeout)throw Error('Timeout '+label);if(Date.now()>next){next=Date.now()+1000;await page.keyboard.press('F8');}
  if(surfaceChecks&&state?.loadingFlow?.visible&&state.loadingFlow.pageFrames>=2){const key=networkPhase+'-'+(state.loading?.phase||state.loader?.phase||state.loadingFlow.phase);if(!captured.has(key)){captured.add(key);await page.screenshot({path:path.join(out,key+'.png')});}}
  await sleep(100);}}
 await cdp.send('Profiler.enable');await cdp.send('Profiler.setSamplingInterval',{interval:2000});await cdp.send('Profiler.start');
 const start=Date.now();await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
 if(surfaceChecks){await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:path.join(out,'browser-startup.png')});}
 await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active&&s.widgets?.length,'hall');
 const bootMs=Date.now()-start;
 const boot=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,'boot.cpuprofile'),JSON.stringify(boot.profile));
 saveNetwork();fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));
 console.log(JSON.stringify({stage:'hall',ms:bootMs,top:summary(boot.profile).slice(0,12),out}));
 if(surfaceChecks){
  await page.keyboard.press('F12');await wait(s=>s.tutorial?.visible,'tutorial');
  for(let i=0;i<24&&state.tutorial.id!=='choose';i++){await page.keyboard.press('Space');await sleep(180);await page.keyboard.press('F8');await sleep(150);}
  await wait(s=>s.tutorial.id==='choose'&&s.tutorial.lineAge>=6,'complete choice text',20000);
  await page.screenshot({path:path.join(out,'tutorial-choice-pc.png')});
  await page.setViewportSize({width:2000,height:900});await sleep(600);await page.screenshot({path:path.join(out,'tutorial-choice-20-9.png')});
  await page.setViewportSize({width:1920,height:1080});await sleep(500);
  for(let i=0;i<6&&state.tutorial.running;i++){
   await page.keyboard.press('F8');await sleep(250);await page.keyboard.press('F8');await sleep(250);
   const b=state.tutorial.buttons.find(b=>b.id==='skip');if(!b)throw Error('Missing skip button');
   await page.mouse.click((b.x+b.w/2)/state.width*1920,(b.y+b.h/2)/state.height*1080);
   await sleep(250);await page.keyboard.press('F8');await sleep(250);
  }
  await wait(s=>!s.tutorial.running,'tutorial closed',10000);
 }
 if(webglTiming){fs.writeFileSync(path.join(out,'webgl-boot.json'),JSON.stringify(await page.evaluate(()=>window.__voxG0WebGL)));await page.evaluate(()=>{window.__voxG0WebGL.phase='crater';});}
 await page.keyboard.press('f');await wait(s=>s.tab==='battle','battle menu');
 const b=state.widgets.find(w=>w.text==='开始匹配'),r=b.rect;networkPhase='crater';await cdp.send('Profiler.start');const battleStart=Date.now();
 await page.mouse.click((r[0]+r[2]/2)/state.width*1920,(r[1]+r[3]/2)/state.height*1080);
 await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'crater');
 const battle=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,'crater.cpuprofile'),JSON.stringify(battle.profile));
 const result={identity:identity.servedManifest,bootMs,craterMs:Date.now()-battleStart,surfaceChecks,capturedSurfaces:[...captured],bootTop:summary(boot.profile),craterTop:summary(battle.profile),states};
 result.frames=await page.evaluate(()=>window.__voxG0Frames);fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(result));
 if(webglTiming){const gl=await page.evaluate(()=>window.__voxG0WebGL);fs.writeFileSync(path.join(out,'webgl.json'),JSON.stringify(gl));console.log(JSON.stringify({stage:'webgl',methods:gl.methods,slowest:gl.slow.toSorted((a,b)=>b.ms-a.ms).slice(0,15)}));}
 await page.screenshot({path:path.join(out,'crater.png')});console.log(JSON.stringify({stage:'crater',ms:result.craterMs,top:result.craterTop.slice(0,15),out}));
 fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));
 saveNetwork();
}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
