const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(c=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(c.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const prefix='salvage-web-'+test.name,report={build:prepared.source_directory,manifest:path.basename(prepared.manifest_path),viewport:test,checks:[],errors:[],httpFailures:[],samples:[]};
  let state,seq=0;fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){try{state=JSON.parse(line.slice(i+14));seq++;}catch(e){if(line.trimEnd().endsWith('}'))report.errors.push(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  async function wait(fn,label,timeout=180000){const at=Date.now();let next=at+1000;while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));
   if(Date.now()>next){next=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);
  }return state;}
  async function dump(){const old=seq;await page.keyboard.down('F8');await sleep(100);await page.keyboard.up('F8');await wait(()=>seq>old,'dump',15000);return state;}
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function point(rect){const [x,y,w,h]=rect,canvas=await page.locator('canvas').boundingBox();return [canvas.x+(x+w/2)/state.width*canvas.width,canvas.y+(y+h/2)/state.height*canvas.height];}
  async function click(text,kind){await dump();const item=state.widgets.find(w=>w.text===text&&(!kind||kind===w.kind)&&!w.disabled);assert.ok(item,'Missing '+text);const [x,y]=await point(item.rect);if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function shot(name){await dump();report.samples.push(structuredClone(state));await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar','hall');await sleep(4000);await shot('home');
   if(!test.touch){await page.mouse.click(test.width*.5,test.height*.5);const cta=state.widgets.find(w=>w.kind==='cta-main'),[x,y]=await point(cta.rect);await page.mouse.move(x,y,{steps:4});await sleep(400);await dump();
    const motion=state.widgets.find(w=>w.kind==='cta-main').sourceMotion;check(motion.x.value===-2&&motion.y.value===-3,'CTA source hover translation');await shot('home-hover');
    await page.mouse.down();await sleep(120);await dump();const press=state.widgets.find(w=>w.kind==='cta-main').sourceMotion;
    check(press.x.value===3&&press.y.value===4,'CTA source press translation');await shot('home-press');await page.mouse.move(test.width-10,10);await page.mouse.up();
   }
   await click('保存到车位');await sleep(500);await dump();
   if(state.dialog){await click('保存');await wait(s=>!s.dialog,'save completed');}
   await click('打捞行动');await wait(s=>s.tab==='salvage'&&s.warehouse?.ready,'warehouse');await shot('warehouse');
   check(state.warehouse.effects.particles===900&&state.warehouse.effects.uploads===1,'warehouse GPU dust uploaded once');const time=state.warehouse.effects.time;
   const crane=state.warehouse.motion.nodes.bridge.position[2],head=state.warehouse.motion.nodes.head.quaternion[1];
   await sleep(900);await dump();check(state.warehouse.effects.time>time&&state.warehouse.effects.uploads===1,'warehouse animation advances without geometry rebuild');
   check(state.warehouse.motion.nodes.bridge.position[2]!==crane&&state.warehouse.motion.nodes.head.quaternion[1]!==head,'authored crane and trader joints animate in production warehouse');
   await shot('warehouse-moving');
   await click('商人','tab');await sleep(1200);await shot('warehouse-trader');
   check(state.warehouse.motion.nodes.bot.position.length===3,'trader remains articulated in market camera');
   await click('整备','tab');
   await click('出发');await wait(s=>s.mode==='trial'&&s.map==='salvage'&&!s.loadingFlow.active,'salvage loading',240000);await shot('spawn');
   const before=state.salvageRun.time;
   if(test.touch)await page.touchscreen.tap(test.width*.5,test.height*.5);else await page.mouse.click(test.width*.5,test.height*.5);
   await wait(s=>s.pointer.captured,'capture');await sleep(2200);await dump();check(state.salvageRun.time>before+1,'actual salvage clock advances');check(state.vehicle.position[1]>-100,'spawn supported by terrain');
   await shot('running');
   async function key(name){await page.keyboard.down(name);await sleep(100);await page.keyboard.up(name);}
   await key('F4');if(test.touch)await click('搜刮');else await key('e');
   await wait(s=>s.salvageRun?.search,'actual search');check(!!state.salvageRun.search,test.touch?'touch search button opens production crate':'E opens production crate');await shot('search');
   await key('F11');await wait(s=>s.salvageRun?.lootPulse?.id,'rare reveal fixture');await shot('rare-reveal');
   check(state.salvageRun.used>0,'production search fills cargo');
   check((state.salvageRun.audio.counts.reveal4||0)>0&&state.salvageRun.audio.voices<=4,'real rarity reveal plays original decoded audio with bounded voices');
   report.fixtures=['F4 relocates to a source supply crate','F11 supplies one rarity-4 item to production search rules','F7 relocates to an eligible source extraction'];
   await key('F7');await wait(s=>s.salvageRun?.result,'actual extraction',90000);await shot('result');
   check(state.salvageRun.result.ok&&state.salvageRun.committed,'actual extraction commits cargo');
   check(!state.pointer.captured,'result releases driving input');
   check(!state.salvageRun.audio.active,'result stops loot audio');
   if(test.touch)await click('回大厅');else await key('Enter');
   await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'return');await shot('returned');
   check(!state.mouse.overlay,'result overlay released after return');
   check(state.lobby==='salvage','returns to correct lobby');check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
  }catch(e){report.result='FAIL';report.failure=e.stack;report.lastState=state;await page.screenshot({path:path.join(out,prefix+'-failure.png')}).catch(()=>{});throw e;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length}));
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
