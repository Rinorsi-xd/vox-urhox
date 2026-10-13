const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),'utf8'));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[],route:'QA moves player to original sites and destroys native opponents; natural timers, dialogue, real held G/touch cleaning, boss retreat, results and restart execute. Not a complete manual driving test.'};
  const prefix='capture-web-'+test.name;let state,sequence=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(line.slice(i+14));sequence++;if(state.story?.id)report.samples.push(state.story);}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Browser renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function wait(predicate,label,timeout=180000){const at=Date.now();let nextDump=at+1000;while(!state||!predicate(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));if(Date.now()>nextDump){nextDump=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);}return state;}
  async function dump(){const before=sequence;await page.keyboard.press('F8');await wait(()=>sequence>before,'state probe',10000);return state;}
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function widget(text){const s=await dump();const item=s.widgets.find(w=>w.text===text);assert.ok(item,'Live widget '+text);const [x,y,w,h]=item.rect;
   check(w>0&&h>0&&x>=0&&y>=0&&x+w<=s.width+1&&y+h<=s.height+1,'interactive '+text+' fits viewport');await tap((x+w/2)/s.width*test.width,(y+h/2)/s.height*test.height);}
  async function shot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  async function destroy(){await page.keyboard.press('F2');await wait(s=>s.story.enemies===0,'native opponents destroyed',15000);}
  async function scrub(){
   if(test.touch){const s=await dump(),[x,y,w,h]=s.touchRects.interact,cdp=await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:(x+w/2)/s.width*test.width,y:(y+h/2)/s.height*test.height,id:1}]});
    await sleep(2200);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
   }else{await page.keyboard.down('g');await sleep(2200);await page.keyboard.up('g');}
  }
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar','hall');await widget('出战');await wait(s=>s.tab==='battle','modes');await widget('剧情模式');
   await wait(s=>s.tab==='story'&&s.story?.ready,'story page');await widget('04  偷家');await wait(s=>s.story?.level===4&&s.story.ready,'capture briefing');await shot('briefing');await widget('开始任务');
   await wait(s=>s.loadingFlow.visible,'loading');await shot('loading');await wait(s=>s.mode==='trial'&&s.story?.id==='s4'&&!s.loadingFlow.active,'capture scene');
   check(state.loadingFlow.warmFrames>=2&&state.story.collectorModels===3,'original three sites visible after rendered readiness');
   if(!test.touch){await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'capture');check(await page.evaluate(()=>!!document.pointerLockElement),'real browser pointer lock');}
   for(const [index,id] of ['A','B','C'].entries()){
    await wait(s=>s.story.step===id,'next site '+id);
    if(id==='B'){
     await wait(s=>s.story.choice?.id==='tag','source graffiti choice');await shot('choice');
     if(test.touch)await widget(state.story.choice.options[1].label);else await page.keyboard.press('2');
     await wait(s=>s.story.flags.tag===1&&!s.story.choice,'graffiti choice applied');check(state.story.flags.tag===1,'original graffiti reply retained');
    }
    await page.keyboard.press('F4');await wait(s=>s.story.enemies===3&&s.story.cap.phase==='cap','actual guards '+id);await shot(id+'-guards');
    if(id==='C'){const kills=state.story.stats.kills;await page.keyboard.press('F10');await wait(s=>s.story.flags.huhuFled,'real damaged boss flees');
     check(state.story.stats.kills===kills,'boss retreat does not award destruction');await shot('retreat');}
    await destroy();await page.keyboard.press('F4');await wait(s=>s.story.cap.phase==='counter'&&s.story.enemies===3,'uncontested source capture '+id,30000);
    check(state.story.stats.sites===index+1,'site '+id+' captured at source duration');await shot(id+'-counter');await destroy();
    await wait(s=>s.story.cap.phase==='scrub','counterattack cleared '+id);await page.keyboard.press('F4');await wait(s=>s.story.inside,'source cleaning reach '+id,10000);
    await scrub();await wait(s=>s.story.stats.graffiti===index+1,'held interact cleans '+id,15000);check(state.story.stats.graffiti===index+1,'actual '+(test.touch?'touch':'keyboard')+' held cleaning '+id);
   }
   await wait(s=>s.story.finished,'natural completion dialogue',150000);await sleep(700);await dump();await shot('result');
   check(state.story.saved&&state.story.stats.sites===3&&state.story.stats.graffiti===3,'three recovered sites save source result');
   await widget('再来一次');await wait(s=>s.mode==='trial'&&s.story?.id==='s4'&&s.story.stats.kills===0&&!s.loadingFlow.active,'restart same mission');
   check(state.story.id==='s4','restart retains capture mission');await wait(s=>s.story.time>.6,'input ready',10000);await page.keyboard.press('t');
   await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');await sleep(1000);await dump();
   check(state.performance.arrayBytes===0,'capture exit releases terrain arrays');check(report.errors.length===0,'no unexpected Web runtime errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await shot('failure').catch(()=>{});throw e;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
