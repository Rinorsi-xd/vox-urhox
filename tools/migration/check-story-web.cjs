const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const build=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),'utf8'));
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{name:'pc',width:1920,height:1080},{name:'phone-landscape',width:840,height:378,dpr:3,touch:true},{name:'tablet',width:1024,height:768,dpr:2,touch:true}];
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr||1,...(test.touch?{hasTouch:true,isMobile:true}:{})});
  const cdp=test.touch?await page.context().newCDPSession(page):null;
  const report={build:build.source_directory,manifest:path.basename(build.manifest_path),viewport:test,checks:[],errors:[],truncatedProbes:0,httpFailures:[],samples:[],route:'QA positions actual player; real objective predicates and keyboard/touch installation. Not a fully manually driven route.'};
  const prefix='story-web-'+test.name;let state,sequence=0;
  fs.writeFileSync(path.join(out,prefix+'.log'),'');
  page.on('console',msg=>{const line=msg.text();fs.appendFileSync(path.join(out,prefix+'.log'),line+'\n');const i=line.indexOf('OUTGAME_STATE ');
   if(i>=0){const payload=line.slice(i+14);try{state=JSON.parse(payload);sequence++;if(state.story)report.samples.push(state.story);}catch(e){
    if(!payload.trimEnd().endsWith('}'))report.truncatedProbes++;else report.errors.push(e.message);
   }}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });
  page.on('pageerror',e=>report.errors.push(e.message));page.on('crash',()=>report.errors.push('Browser renderer crashed'));
  page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({status:r.status(),url:r.url()});});
  const check=(ok,label)=>{assert.ok(ok,label);report.checks.push(label);};
  async function wait(pred,label,timeout=180000){const at=Date.now();while(!state||!pred(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-at>timeout)throw Error('Timeout '+label+' '+JSON.stringify(state));await sleep(80);
  }return state;}
  async function dump(){const before=sequence;await page.keyboard.press('F8');await wait(()=>sequence>before,'state probe',10000);return state;}
  async function shot(name){await page.screenshot({path:path.join(out,prefix+'-'+name+'.png')});}
  async function tap(x,y){if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
  async function widget(text){const s=await dump();const item=s.widgets.find(item=>item.text===text);assert.ok(item,'Live widget '+text);const [x,y,w,h]=item.rect;await tap((x+w/2)/s.width*test.width,(y+h/2)/s.height*test.height);}
  async function jump(next){await page.keyboard.press('F4');await wait(s=>s.story.step===next,'objective '+next,20000);}
  async function install(next,count){
   await page.keyboard.press('F4');await wait(s=>s.story.inside,'installation ring',10000);
   await sleep(250);check(state.story.install===0,'standing in ring cannot install without input');
   if(!test.touch)await page.keyboard.down('g');else{
    const s=await dump(),r=s.touchRects.interact;assert.ok(r,'native touch installation button');
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:(r[0]+r[2]/2)/s.width*test.width,y:(r[1]+r[3]/2)/s.height*test.height,id:7}]});
   }
   await wait(s=>s.story.install>0,'real installation input',10000);await shot('install-'+count);
   await wait(s=>s.story.step===next,'held install '+next,15000);
   if(!test.touch)await page.keyboard.up('g');else await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   check(state.story.stats.collectors===count&&state.story.collectorModels===count,'source collector '+count+' lands through objective event');
  }
  try{
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&s.tab==='hangar','hall');await widget('出战');await wait(s=>s.tab==='battle','mode picker');
   await widget('剧情模式');await wait(s=>s.tab==='story'&&s.story?.ready,'story page');await shot('briefing');await widget('开始任务');
   await wait(s=>s.loadingFlow?.visible&&!s.loadingFlow.failed,'real loading');await shot('loading');
   await wait(s=>s.mode==='trial'&&s.story?.id==='s1'&&!s.loadingFlow.active,'first mission');
   check(state.loadingFlow.warmFrames>=2&&state.sceneVisible,'mission starts only after rendered scene ready');
   if(!test.touch){await page.mouse.click(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'pointer lock');}
   await wait(s=>s.story.step==='box'&&s.story.voicePlayed>0,'natural opening voice');await shot('live');
   check(state.story.voicePlaying,'original voice plays through Web SoundSource');
   await jump('exit');check(state.story.stats.intel===1,'real contact collects original black box');await jump('poster');await jump('deck');
   check(state.story.stats.intel===2,'highland pickup preserved');
   await page.keyboard.press('F6');await wait(s=>!s.story.alive&&s.story.stats.deaths===1,'native player destruction');await shot('death');
   await wait(s=>s.story.alive,'three second checkpoint respawn',10000);check(state.story.step==='deck'&&state.story.stats.intel===2,'checkpoint preserves completed objectives');
   await install('bow',1);await install('scouts',2);await page.keyboard.press('F4');
   await wait(s=>s.story.phase==='fight'&&s.story.enemies===3,'original pirate encounter');await shot('pirates');
   await sleep(2500);check(state.story.alive,'player remains controllable during actual enemy AI');
   await page.keyboard.press('F2');await wait(s=>s.story?.step==='log'&&s.story.stats.kills===3,'real enemy removal and dropped log');
   await jump('east');check(state.story.stats.intel===3,'dropped pirate log is picked by player');await install('home',3);
   await page.keyboard.press('F4');await wait(s=>s.story.phase==='complete','final reach');
   await wait(s=>s.story.finished,'natural completion dialogue and result',120000);await sleep(700);await dump();await shot('result');
   check(state.story.grade==='A'&&state.story.saved,'one loss yields source A grade and saves progression');
   check(!state.pointer.captured,'result releases pointer');
   await widget('返回剧情页');await wait(s=>s.mode==='hangar'&&s.tab==='story'&&!s.loadingFlow.active,'story return');
   check(state.performance.arrayBytes===0&&!state.craterModelResident,'return frees crater arrays and models');await shot('return');
   await widget('开始任务');await wait(s=>s.mode==='trial'&&s.story?.id==='s1'&&!s.loadingFlow.active,'reenter story');
   if(!test.touch){await page.mouse.click(test.width*.5,test.height*.5);await wait(s=>s.pointer.captured,'reenter pointer');}
   await wait(s=>s.story.step==='box','fresh first objective');check(state.story.stats.intel===0&&state.story.stats.deaths===0,'reentry resets mission run');
   if(!test.touch){await page.keyboard.press('Escape');await wait(s=>!s.pointer.captured,'pause');}
   await page.keyboard.press('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'second return');
   check(state.performance.arrayBytes===0,'second return releases arrays');check(report.errors.length===0,'no unexpected runtime errors');report.result='PASS';
  }catch(error){report.result='FAIL';report.failure=error.stack;report.lastState=state;await shot('failure').catch(()=>{});throw error;}
  finally{fs.writeFileSync(path.join(out,prefix+'.json'),JSON.stringify(report,null,2));await page.close();}
  console.log(JSON.stringify({case:test.name,result:report.result,checks:report.checks.length,errors:report.errors.length,httpFailures:report.httpFailures.length}));
 }}finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
