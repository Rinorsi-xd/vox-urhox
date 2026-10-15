const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const prefix='reticle-web-'+test.name,report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[]};
  let state,seq=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(line.slice(i+14));seq++;}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  async function wait(fn,label,timeout=150000){const at=Date.now();let next=at+1000;while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
   if(Date.now()>next){next=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);
  }return state;}
  async function dump(){const old=seq;await page.keyboard.press('F8');await wait(()=>seq>old,'dump',10000);return state;}
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function shot(name){await dump();report.samples.push(structuredClone(state));await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  async function touchButton(key){const [x,y,w,h]=state.touchRects[key];await tap((x+w/2)/state.width*test.width,(y+h/2)/state.height*test.height);}
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow.active,'hall');
   await page.keyboard.press('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active,'trial');
   await tap(test.width/2,test.height/2);await wait(s=>s.pointer.captured,'capture');await shot('frame');
   check(state.reticle.fire.word==='就绪','source fire readout uses actual mounted weapon');
   check(!state.reticle.legacyMeter,'obsolete speed panel hidden');
   check(Math.abs(state.reticle.layout.radius-270*Math.min(state.width/1920,state.height/1080))<1e-5,'source landscape reticle geometry');
   if(test.touch){
    const cards=state.widgets.filter(w=>w.kind==='weapon'&&w.rect[2]>0&&w.rect[3]>=44&&w.text==='');
    check(cards.length===state.reticle.groups,'each weapon retains a touch button');
    check(cards.every(({rect:[x,y,w,h]})=>x>=0&&y>=0&&x+w<=state.width&&y+h<=state.height),'touch weapon buttons within viewport');
    check(cards.every((a,i)=>cards.every((b,j)=>i===j||a.rect[0]+a.rect[2]<=b.rect[0]||b.rect[0]+b.rect[2]<=a.rect[0]||a.rect[1]+a.rect[3]<=b.rect[1]||b.rect[1]+b.rect[3]<=a.rect[1])),'touch weapon buttons do not overlap');
    const item=cards[1];
    check(!!item,'touch weapon switch retains usable target');
    const [x,y,w,h]=item.rect;await tap((x+w/2)/state.width*test.width,(y+h/2)/state.height*test.height);
   }else await page.keyboard.press('2');
   await wait(s=>s.reticle.selected===2,'sniper selection');await shot('sniper');check(state.reticle.fire.word==='就绪','sniper fire state ready');
   if(test.touch)await touchButton('scope');else await page.mouse.down({button:'right'});
   await wait(s=>s.reticle.scope&&Math.abs(s.reticle.fov-12.704159)<.2,'source sniper optics');await shot('scope');
   check(state.reticle.fov<13,'sniper uses four-times source zoom');
   if(test.touch)await touchButton('scope');else await page.mouse.up({button:'right'});
   await wait(s=>!s.reticle.scope,'scope release');
   if(!test.touch){await page.keyboard.press('1');await page.mouse.down();await wait(s=>s.reticle.fire.word==='预热'||s.weapons.shots>0,'real weapon warmup');await shot('fire');await page.mouse.up();}
   await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');check(!state.reticle,'HUD lifecycle released');
   check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
