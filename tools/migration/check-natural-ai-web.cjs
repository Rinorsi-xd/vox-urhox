const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence'),base='http://127.0.0.1:'+(process.env.VOX_QA_PORT||'4269');
const test=process.env.VOX_QA_CASE==='phone-landscape'?{name:'phone-landscape',width:840,height:378,dpr:3,touch:true}:{name:'pc',width:1920,height:1080};
const prefix='natural-ai-web-'+test.name;const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{isMobile:true,hasTouch:true}:{})});
const report={base,viewport:test,checks:[],errors:[],httpFailures:[],traces:[],frames:[],route:'Production mode selection and matching, real pointer capture or touch, held manual throttle for 12 seconds, then natural 60-second AI battle. No injected positions, damage, kills, round advances, or simulation speed. Desktop browser emulation is not mobile hardware acceptance.'};
let state,seq=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;if(state.frames)report.frames.push(state.frames);}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);});
page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Browser renderer crashed'));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
async function wait(fn,label,timeout=240000){const t=Date.now();let probe=t;while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-t>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));if(Date.now()-probe>1000){probe=Date.now();await page.keyboard.press('F8');}await sleep(100);}return state;}
async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'fresh QA state',20000);}
async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
async function widget(text){await dump();const s=await wait(s=>s.widgets.some(w=>w.text===text&&w.rect[2]>0&&w.rect[3]>0),'laid out '+text,30000),item=s.widgets.find(w=>w.text===text);check(item,'live '+text);const [x,y,w,h]=item.rect;await tap((x+w/2)/s.width*test.width,(y+h/2)/s.height*test.height);}
async function shot(name){const file=path.join(out,prefix+'-'+name+'.png');await page.screenshot({path:file});check((await sharp(file).stats()).channels.slice(0,3).some(c=>c.stdev>20),'nonblank '+name);}
try{
 const identity=await (await fetch(base+'/identity.json')).json();report.build=identity.source_directory;report.manifest=identity.servedManifest;report.identity=identity;
 const started=Date.now();await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');await wait(s=>s.mode==='hangar'&&s.tab==='hangar'&&!s.loadingFlow.active,'first actionable hall');report.hallMs=Date.now()-started;
 await widget('出战');await widget('歼灭战');const load=Date.now();await widget('开始匹配');await wait(s=>s.mode==='trial'&&s.battle&&!s.loadingFlow.active,'actual crater battle');report.battleLoadMs=Date.now()-load;
 if(state.intro?.active){await page.keyboard.press('Space');await wait(s=>!s.intro?.active,'intro releases game');}
 await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'actual player control');await wait(s=>s.battle.state==='live','natural preparation finishes');
 const start=structuredClone(await dump());report.traces.push(start);await shot('start');
 let touchSession;
 if(test.touch){
  const [x,y,w,h]=state.touchControls.rects.stick;const kx=test.width/state.width,ky=test.height/state.height;touchSession=await page.context().newCDPSession(page);
  await touchSession.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:(x+w/2)*kx,y:(y+h/2)*ky,id:1}]});
  await touchSession.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:(x+w/2)*kx,y:(y+h/2-h*.4)*ky,id:1}]});
 }else await page.keyboard.down('w');
 const seconds=Number(process.env.VOX_QA_NATURAL_SECONDS||60);for(let i=0;i<seconds;i++){
  if(i===12){if(touchSession){await touchSession.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await touchSession.detach();touchSession=null;}else await page.keyboard.up('w');}
  await sleep(1000);await dump();report.traces.push(structuredClone(state));if(state.battle?.state==='over')break;
 }
 if(touchSession){await touchSession.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await touchSession.detach();}else await page.keyboard.up('w');
 const live=await dump();await shot('natural-combat');
 const moved=[];for(const initial of start.battle.units.filter(u=>!u.player)){let maximum=0;for(const trace of report.traces){const u=trace.battle?.units.find(v=>v.name===initial.name);if(u?.position)maximum=Math.max(maximum,Math.hypot(u.position[0]-initial.position[0],u.position[2]-initial.position[2]));}moved.push({name:initial.name,metres:maximum});}
 report.moved=moved;report.modes=[...new Set(report.traces.flatMap(s=>s.battle?.units.map(u=>u.mode).filter(Boolean)||[]))];
 check(moved.filter(u=>u.metres>3).length>=2,'multiple Web AI naturally travel more than 3 metres');check(report.modes.length>=2,'source Web AI naturally switches tactical modes');
 check(report.traces.some(s=>s.battle.units.some(u=>u.hp<.999||!u.alive)||s.weapons.hits>0),'real enemy weapons naturally damage battle vehicles');
 check(live.performance.fixedSteps>start.performance.fixedSteps,'battle advances real fixed simulation steps');
 await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured,'release gameplay pointer');
 await widget('退出对局');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'returns to actual hall');check(state.performance.arrayBytes===0,'battle return releases terrain arrays');
 report.gameHttpFailures=report.httpFailures.filter(f=>!f.url.includes('/cached-engine-source/')||!f.url.includes('assets@windows.7z'));check(report.errors.length===0&&report.gameHttpFailures.length===0,'no Lua shader browser or game resource errors');report.result='PASS';
}catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await browser.close();console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length,hallMs:report.hallMs,battleLoadMs:report.battleLoadMs}));}
})().catch(e=>{console.error(e);process.exitCode=1;});
