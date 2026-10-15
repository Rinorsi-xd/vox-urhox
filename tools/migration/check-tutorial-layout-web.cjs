const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),port=Number(process.env.VOX_QA_PORT||4258),base='http://127.0.0.1:'+port;
const out=path.join(root,'docs/migration/evidence/tutorial-layout',new Date().toISOString().replace(/[:.]/g,'-'));
fs.mkdirSync(out,{recursive:true});
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const cases=[{id:'pc',width:1920,height:1080},{id:'pc-small',width:1280,height:720},{id:'desktop-20-9',width:2000,height:900},{id:'touch-20-9',width:840,height:378,dpr:3,touch:true}];
(async()=>{
 const identity=await fetch(base+'/identity.json').then(r=>r.json());
 assert.equal(identity.qa,true,'layout probes require explicit QA server');
 fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(identity,null,2));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={identity:identity.servedManifest,sourceCommit:identity.identity.sourceCommit,checks:[],cases:[],errors:[],httpFailures:[],scope:'Actual tutorial advancement and two clicks, measured nonoverlap including the full confirmation label. Desktop and emulated touch are not real-device performance acceptance.'};
 try{
  for(const touch of [false,true]){
   const group=cases.filter(c=>!!c.touch===touch);
   const first=group[0];
   const context=await browser.newContext({viewport:{width:first.width,height:first.height},deviceScaleFactor:first.dpr||1,...(touch?{isMobile:true,hasTouch:true}:{})});
   const page=await context.newPage();let state,seq=0;
   page.on('console',m=>{const line=m.text();const at=line.indexOf('OUTGAME_STATE ');if(at>=0){try{state=JSON.parse(line.slice(at+14));seq++;}catch{}}
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
   });
   page.on('pageerror',e=>report.errors.push(e.message));
   page.on('response',r=>{if(r.status()>=400)report.httpFailures.push({url:r.url(),status:r.status()});});
   async function wait(pred,label,timeout=240000){const start=Date.now();let next=start+1000;while(!state||!pred(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>timeout)throw Error('Timeout '+label);if(Date.now()>next){next=Date.now()+1000;await page.keyboard.press('F8');}await sleep(80);}return state;}
   async function dump(){const before=seq;await page.keyboard.press('F8');return wait(()=>seq>before,'fresh state',15000);}
   function check(ok,label){assert.ok(ok,label);report.checks.push(label);}
   async function tap(rect,test){const x=(rect.x+rect.w/2)/state.width*test.width,y=(rect.y+rect.h/2)/state.height*test.height;return touch?page.touchscreen.tap(x,y):page.mouse.click(x,y);}
   function layout(test,phase){
    const t=state.tutorial,r=t.card;
    check(t.buttons.length===3,test.id+' '+phase+' route choices and skip present');
    for(const b of t.buttons){check(b.x>=r.x-.1&&b.y>=r.y-.1&&b.x+b.w<=r.x+r.w+.1&&b.y+b.h<=r.y+r.h+.1,test.id+' '+phase+' '+b.id+' fits tutorial card');
     check(b.x>=0&&b.y>=0&&b.x+b.w<=state.width+.1&&b.y+b.h<=state.height+.1,test.id+' '+phase+' '+b.id+' fits viewport');}
    for(let i=0;i<t.buttons.length;i++)for(let j=i+1;j<t.buttons.length;j++){const a=t.buttons[i],b=t.buttons[j];check(a.x+a.w<=b.x||b.x+b.w<=a.x||a.y+a.h<=b.y||b.y+b.h<=a.y,test.id+' '+phase+' '+a.id+'/'+b.id+' do not overlap');}
    return structuredClone(t);
   }
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active,'hall');
   for(const test of group){
    await page.setViewportSize({width:test.width,height:test.height});await sleep(500);
    await page.keyboard.press('F12');await wait(s=>s.tutorial?.visible&&s.tutorial.id==='hello','tutorial start');
    for(let i=0;i<24&&state.tutorial.id!=='choose';i++){await page.keyboard.press('Space');await sleep(180);await dump();}
    await wait(s=>s.tutorial.id==='choose','choice');await dump();
    const initial=layout(test,'normal'),skip=initial.buttons.find(b=>b.id==='skip');
    await page.screenshot({path:path.join(out,test.id+'-normal.png')});
    await tap(skip,test);await dump();
    const confirm=layout(test,'confirm'),expanded=confirm.buttons.find(b=>b.id==='skip');
    check(expanded.text==='确定跳过？再点一次',test.id+' original confirmation text rendered');
    check(expanded.y===skip.y,test.id+' confirmation stays on same row');
    const oldX=skip.x+skip.w/2,oldY=skip.y+skip.h/2;
    check(oldX>=expanded.x&&oldX<expanded.x+expanded.w&&oldY>=expanded.y&&oldY<expanded.y+expanded.h,test.id+' first click remains inside confirmation target');
    await page.screenshot({path:path.join(out,test.id+'-confirm.png')});
    await tap(skip,test);await wait(s=>!s.tutorial.running,'confirmed skip',10000);
    check(!state.build&&state.tab==='hangar'&&state.tutorial.record.skipped,test.id+' same-position second click skips without selecting a route');
    report.cases.push({test,initial,confirm});
   }
   await context.close();
  }
  report.result='PASS';
 }catch(e){report.result='FAIL';report.failure=e.stack;process.exitCode=1;}
 finally{fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));await browser.close();}
 console.log(JSON.stringify({result:report.result,checks:report.checks.length,errors:report.errors.length,failure:report.failure,out}));
})().catch(e=>{console.error(e);process.exitCode=1;});
