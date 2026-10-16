// Optional narrow route of check-livery-web: public UI and actual mouse/CDP touches.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),base=process.env.VOX_QA_BASE||'http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4337);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const expected='4d0114c4a25d7e37f67190383286601784c0940b468199cc41f22bd3972b5847';
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa,'QA observer required');
 assert.equal(identity.identity.scripts['controls/LiveryControls.lua'],expected,'Package must contain frozen livery gesture increment');
 if(process.env.VOX_EXPECT_MANIFEST)assert.equal(identity.servedManifest,process.env.VOX_EXPECT_MANIFEST,'Pinned final package');
 const out=path.join(root,'docs/migration/evidence/livery-gestures-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});console.log(out);
 const report={identity,checks:[],states:[],errors:[],boundary:'Public livery tab and actual mouse/CDP touch events. QA state is read-only observation; no injected game state. Desktop and emulated landscape input only; not real-phone performance or full visual parity.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const cases=[{name:'pc',width:1920,height:1080,dpr:1},{name:'20x9',width:840,height:378,dpr:3,touch:true}];
 const check=(ok,label)=>{report.checks.push({label,pass:!!ok});assert(ok,label);};
 try{for(const test of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36'}:{})});
  let state,revision=0,closed=false;const deadline=Date.now()+240000;
  page.on('console',m=>{const line=m.text();fs.appendFileSync(path.join(out,test.name+'.log'),line+'\n');const at=line.indexOf('OUTGAME_STATE ');
   if(at>=0){try{state=JSON.parse(line.slice(at+14));revision++;}catch{report.truncated=(report.truncated||0)+1;}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push({case:test.name,error:line});
  });page.on('pageerror',e=>report.errors.push({case:test.name,error:String(e)}));page.on('crash',()=>{closed=true;report.errors.push({case:test.name,error:'Renderer crashed'});});
  async function wait(fn,label){let next=0;while(!state||!fn(state)){
   if(closed||report.errors.length)throw Error(label+': '+JSON.stringify(report.errors.at(-1)));if(Date.now()>deadline)throw Error('Timeout '+label);
   if(Date.now()>next){next=Date.now()+700;await page.keyboard.press('F8');}await sleep(70);
  }}
  async function dump(){const previous=revision;await page.keyboard.press('F8');await wait(()=>revision>previous,'fresh observation');return state;}
  async function point(x,y){const r=await page.locator('canvas').boundingBox();return {x:r.x+x/state.width*r.width,y:r.y+y/state.height*r.height};}
  async function click(text){await dump();const w=state.widgets.find(w=>w.text===text&&!w.disabled);assert(w,'Public control '+text);const r=w.rect,p=await point(r[0]+r[2]/2,r[1]+r[3]/2);
   if(test.touch)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y,{delay:70});await sleep(200);
  }
  async function capture(name){await dump();report.states.push({case:test.name,stage:name,state:structuredClone(state)});const bytes=await page.screenshot({path:path.join(out,test.name+'-'+name+'.png')});
   check((await sharp(bytes).stats()).channels.slice(0,3).some(c=>c.stdev>15),test.name+' nonblank '+name);
  }
  let cdp;
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&s.sceneVisible&&!s.loadingFlow?.active,'actionable hall');await click('涂装');
   await wait(s=>s.tab==='livery'&&s.livery?.rects?.lib&&s.livery?.rects?.props,'public livery page');await sleep(900);await dump();
   check(!state.livery.pick&&state.livery.selected===0,test.name+' no sticker selected or held at entry');
   const initialList=JSON.stringify(state.livery.list),initialHistory=state.livery.history;
   const lib=state.livery.rects.lib,props=state.livery.rects.props,left=lib[0]+lib[2]+24,right=props[0]-24;
   check(right-left>160,test.name+' usable center canvas between actual side panels');
   const y=Math.min(state.height*.45,lib[1]+lib[3]*.4),a=await point(left+(right-left)*.25,y),b=await point(left+(right-left)*.65,y);
   await capture('before');
   if(test.touch){
    cdp=await page.context().newCDPSession(page);const distance=state.camera.desiredDist;
    check(distance>3,test.name+' starting camera above minimum zoom');
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:11,...a},{id:12,...b}]});
    const outward={x:b.x+(b.x-a.x)*.35,y:b.y};
    for(let i=1;i<=6;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:11,...a},{id:12,x:b.x+(outward.x-b.x)*i/6,y:b.y}]});await sleep(35);}
    await sleep(250);await dump();
    check(state.camera.desiredDist<distance*.9&&state.camera.desiredDist>distance*.55,'20x9 real two-contact pinch zooms smoothly');
    await capture('pinch');const zoom=state.camera.desiredDist,target=state.camera.target.slice();
    for(let i=1;i<=6;i++){const dx=18*i/6,dy=10*i/6;await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:11,x:a.x+dx,y:a.y+dy},{id:12,x:outward.x+dx,y:outward.y+dy}]});await sleep(40);}
    await sleep(400);await dump();
    check(Math.abs(state.camera.desiredDist/zoom-1)<.06,'20x9 parallel translation preserves pinch distance');
    check(state.camera.target.some((v,i)=>Math.abs(v-target[i])>.015),'20x9 real two-contact translation pans camera');
    await capture('pan');await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]});
    await sleep(500);await dump();const yaw=state.camera.yaw;
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:13,...a}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:13,x:a.x+24,y:a.y}]});await sleep(250);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await sleep(350);await dump();
    check(Math.abs(state.camera.yaw-yaw)>1,'20x9 cancel then fresh single contact rotates');
   }else{
    const distance=state.camera.desiredDist;await page.mouse.move(a.x,a.y);await page.mouse.wheel(0,-120);await sleep(450);await dump();
    check(state.camera.desiredDist<distance&&state.camera.desiredDist>distance*.6,'PC actual wheel zoom remains bounded');
    await page.mouse.wheel(0,120);await sleep(450);await dump();check(Math.abs(state.camera.desiredDist/distance-1)<.08,'PC opposite wheel restores camera distance');
    const yaw=state.camera.yaw;await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(a.x+30,a.y+8,{steps:8});await page.mouse.up();await sleep(400);await dump();
    check(Math.abs(state.camera.yaw-yaw)>1,'PC actual left drag rotates background');await capture('mouse');
   }
   check(!state.livery.pick&&state.livery.selected===0&&JSON.stringify(state.livery.list)===initialList&&state.livery.history===initialHistory,test.name+' camera gestures never select place or edit stickers');
   await click('完成');await wait(s=>s.tab==='hangar'&&!s.livery,'public return to hangar');
  }catch(error){report.lastState=state;await page.screenshot({path:path.join(out,test.name+'-failure.png'),timeout:5000}).catch(()=>{});throw error;}
  finally{if(cdp){await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]}).catch(()=>{});await cdp.detach().catch(()=>{});}await page.close();}
 }
 report.result='PASS';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1;}
 finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();}
 console.log(JSON.stringify({out,result:report.result,checks:report.checks.length,errors:report.errors.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});
