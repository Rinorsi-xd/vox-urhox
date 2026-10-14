const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),port=Number(process.env.VOX_G0_PORT||4219),base='http://127.0.0.1:'+port;
const out=path.join(root,'docs/migration/evidence/g0-profile',new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(out,{recursive:true});const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function summary(p){const nodes=new Map(p.nodes.map(n=>[n.id,n])),times=new Map();for(let i=0;i<(p.samples||[]).length;i++)times.set(p.samples[i],(times.get(p.samples[i])||0)+p.timeDeltas[i]);return [...times].map(([id,us])=>({ms:us/1000,...nodes.get(id).callFrame})).sort((a,b)=>b.ms-a.ms).slice(0,40);}
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=d3d11']});
try{
 const gpu=await browser.newBrowserCDPSession(),gpuInfo=await gpu.send('SystemInfo.getInfo');fs.writeFileSync(path.join(out,'gpu.json'),JSON.stringify(gpuInfo.gpu));
 const identity=await fetch(base+'/identity.json').then(r=>r.json());fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity));
 const page=await browser.newPage({viewport:{width:1920,height:1080}}),cdp=await page.context().newCDPSession(page);let state;const logs=[],states=[];
 page.on('console',m=>{const line=m.text();logs.push(line);if(line.includes('OUTGAME_STATE '))try{state=JSON.parse(line.slice(line.indexOf('OUTGAME_STATE ')+14));states.push({at:Date.now(),state});}catch{}});
 await page.addInitScript(()=>{window.__voxG0Frames=[];let prev=0;function tick(now){if(prev)window.__voxG0Frames.push({at:now,ms:now-prev});prev=now;requestAnimationFrame(tick);}requestAnimationFrame(tick);});
 async function wait(pred,label,timeout=300000){const start=Date.now();let next=start+1000;while(!state||!pred(state)){const error=logs.find(l=>/Execute Lua function failed|Aborted\(/.test(l));if(error){fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));throw Error(error);}if(Date.now()-start>timeout)throw Error('Timeout '+label);if(Date.now()>next){next=Date.now()+1000;await page.keyboard.press('F8');}await sleep(100);}}
 await cdp.send('Profiler.enable');await cdp.send('Profiler.setSamplingInterval',{interval:2000});await cdp.send('Profiler.start');
 const start=Date.now();await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
 await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active&&s.widgets?.length,'hall');
 const bootMs=Date.now()-start;
 const boot=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,'boot.cpuprofile'),JSON.stringify(boot.profile));
 console.log(JSON.stringify({stage:'hall',ms:bootMs,top:summary(boot.profile).slice(0,12),out}));
 await page.keyboard.press('f');await wait(s=>s.tab==='battle','battle menu');
 const b=state.widgets.find(w=>w.text==='开始匹配'),r=b.rect;await cdp.send('Profiler.start');const battleStart=Date.now();
 await page.mouse.click((r[0]+r[2]/2)/state.width*1920,(r[1]+r[3]/2)/state.height*1080);
 await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'crater');
 const battle=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,'crater.cpuprofile'),JSON.stringify(battle.profile));
 const result={identity:identity.servedManifest,bootMs,craterMs:Date.now()-battleStart,bootTop:summary(boot.profile),craterTop:summary(battle.profile),states};
 result.frames=await page.evaluate(()=>window.__voxG0Frames);fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(result));
 await page.screenshot({path:path.join(out,'crater.png')});console.log(JSON.stringify({stage:'crater',ms:result.craterMs,top:result.craterTop.slice(0,15),out}));
 fs.writeFileSync(path.join(out,'console.log'),logs.join('\n'));
}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
