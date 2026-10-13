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
  const report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[],route:'QA advances siege beat times and player position; real enemies, failure/retry, choice UI, pickup and result execute. Not a manually driven 120-second defence.'};
  const prefix='siege-web-'+test.name;let state,sequence=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
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
  async function widget(text){const s=await dump();const item=s.widgets.find(w=>w.text===text);assert.ok(item,'Live widget '+text);const [x,y,w,h]=item.rect;check(w>0&&h>0&&x>=0&&y>=0&&x+w<=s.width+1&&y+h<=s.height+1,'interactive '+text+' fits viewport');await tap((x+w/2)/s.width*test.width,(y+h/2)/s.height*test.height);}
  async function shot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  async function reply(index){if(test.touch)await widget(state.story.choice.options[index-1].label);else await page.keyboard.press(String(index));}
  async function destroy(){await page.keyboard.press('F2');await wait(s=>s.story.enemies===0,'pirates destroyed',15000);}
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar','hall');await widget('出战');await wait(s=>s.tab==='battle','modes');await widget('剧情模式');
   await wait(s=>s.tab==='story'&&s.story?.ready,'story page');await widget('03  围剿');await wait(s=>s.story?.level===3&&s.story.ready,'siege briefing');await shot('briefing');await widget('开始任务');
   await wait(s=>s.loadingFlow.visible,'loading');await shot('loading');await wait(s=>s.mode==='trial'&&s.story?.id==='s3'&&!s.loadingFlow.active,'siege scene');
   check(state.loadingFlow.warmFrames>=2,'siege revealed after actual resources and rendered frames');
   if(!test.touch){await tap(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'capture');check(await page.evaluate(()=>!!document.pointerLockElement),'real browser pointer lock');}
   await wait(s=>s.story.step==='gate','gate');await page.keyboard.press('F4');await wait(s=>s.story.choice?.id==='surrender','natural surrender dialogue');await shot('parley');await reply(3);
   await wait(s=>s.story.step==='hold','source reply ends before battle');check(state.story.flags.surrender===2,'source zero-based surrender reply');
   for(const [time,count] of [[8,3],[36,4],[56,0],[66,3],[84,3],[104,5]]){
    await page.keyboard.press('F9');
    if(time===56){await wait(s=>s.story.choice?.id==='lunch','natural lunch interruption',15000);await shot('choice');
     if(test.touch)check(!state.widgets.some(w=>w.text==='开火'||w.text==='安装'),'choices hide overlapping touch action buttons');await reply(2);await wait(s=>s.story.flags.lunch===1&&!s.story.choice,'lunch selected');
    }else{await wait(s=>s.story.enemies===count,'source wave '+time,15000);await shot('wave-'+time);check(state.story.enemies===count,'native source siege wave '+time);await destroy();}
   }
   check(state.story.stats.kills===18,'all eighteen source siege pirates use real destruction');
   await page.keyboard.press('F10');await wait(s=>s.story.failing,'shield collapse');await shot('retry');await wait(s=>!s.story.failing&&s.story.hold.energy===1,'shield generator retry',15000);
   check(state.story.stats.fails===1&&state.story.enemies===0,'retry resets shield and clears actual attackers');
   for(let i=0;i<7;i++){
    await page.keyboard.press('F9');await sleep(500);await dump();
    if(state.story.choice){await reply(1);await sleep(250);}
    if(state.story.enemies>0)await destroy();
   }
   await wait(s=>s.story.step==='coupon'&&s.story.target,'company coupon drop',20000);await shot('coupon');await page.keyboard.press('F4');
   await wait(s=>s.story.finished,'natural completion dialogue',150000);await sleep(700);await dump();await shot('result');
   check(state.story.stats.intel===1&&state.story.saved,'actual coupon pickup saves siege result');
   await widget('再来一次');await wait(s=>s.mode==='trial'&&s.story?.id==='s3'&&s.story.stats.fails===0&&!s.loadingFlow.active,'restart same mission');
   check(state.story.id==='s3','restart retains siege selection');await wait(s=>s.story.time>.6,'input ready',10000);await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');await sleep(1000);await dump();
   check(state.performance.arrayBytes===0,'siege return releases terrain arrays');check(report.errors.length===0,'no unexpected Web runtime errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await shot('failure').catch(()=>{});throw e;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
