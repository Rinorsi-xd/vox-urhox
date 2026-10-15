// Actual target entry screenshots; source CSS capture is in audit-live-source-fonts.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:'+Number(process.env.VOX_QA_PORT||4294);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function main(){
 const identity=await fetch(base+'/identity.json').then(r=>r.json());assert(identity.qa);
 const out=path.resolve('docs/migration/evidence/target-font-pages-'+identity.servedManifest.replace('.json','')+'-'+new Date().toISOString().replace(/[:.]/g,'-'));
 fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 let failed=false;
 try{for(const test of [{name:'pc',width:1920,height:1080},{name:'20-9',width:840,height:378,touch:true,dpr:3}].filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t.name))){
  const context=await browser.newContext({viewport:{width:test.width,height:test.height},hasTouch:!!test.touch,isMobile:!!test.touch,deviceScaleFactor:test.dpr||1});
  const page=await context.newPage();let state,serial=0;
  const report={identity,test,pages:[],errors:[],boundary:'Real target clicks and screenshots. Widget properties do not prove rendered glyph fallback. Concurrent functional browsers; no performance or real-device acceptance.'};
  page.on('console',message=>{const line=message.text();fs.appendFileSync(path.join(out,test.name+'.log'),line+'\n');
   const i=line.indexOf('OUTGAME_STATE ');if(i>=0){try{state=JSON.parse(line.slice(i+14));serial++;}catch{}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(line))report.errors.push(line);
  });page.on('pageerror',e=>report.errors.push(e.message));
  async function wait(fn,label,timeout=180000){const started=Date.now();while(!state||!fn(state)){
   if(report.errors.length)throw Error(report.errors.join('\n'));
   if(Date.now()-started>timeout)throw Error('Timeout '+label);
   await page.keyboard.press('F8');await sleep(300);
  }}
  async function dump(){const before=serial;await page.keyboard.press('F8');await wait(()=>serial>before,'fresh snapshot',15000);return state;}
  async function click(text,icon){await dump();const w=state.widgets.find(w=>!w.disabled&&(icon?w.icon===icon:w.text===text));assert(w,'actual control '+(text||icon));
   const x=(w.rect[0]+w.rect[2]/2)*test.width/state.width,y=(w.rect[1]+w.rect[3]/2)*test.height/state.height;
   if(test.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await sleep(800);await dump();
  }
  async function capture(name){await dump();report.pages.push({name,state:structuredClone(state)});await page.screenshot({path:path.join(out,test.name+'-'+name+'.png')});}
  try{
   await page.goto(base+'/outgame.html?-game_url='+base+'/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar'&&!s.loadingFlow?.active&&!s.loading?.busy,'actionable home');
   if(!test.touch){await click(null,'help');await capture('help');
    if(process.env.VOX_FONT_HELP_SCROLL==='1'){
     const before=state.help?.scrollY||0;
     await page.mouse.move(test.width*.5,test.height*.5);await page.mouse.wheel(0,1600);await sleep(500);await capture('help-bottom');
     assert(state.help&&state.help.scrollY>before,'actual browser wheel scrolls help overlay');
    }
    await page.keyboard.press('Escape');await sleep(400);
   }
   await click(null,'gear');await capture('settings');await page.keyboard.press('Escape');await sleep(400);
   await click('创意工坊');await capture('workshop');report.result='CAPTURED';
  }catch(e){report.result='FAIL';report.failure=e.stack;failed=true;try{await page.screenshot({path:path.join(out,test.name+'-failure.png'),timeout:10000});}catch{}}
  await context.close();fs.writeFileSync(path.join(out,test.name+'.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({name:test.name,result:report.result,pages:report.pages.map(p=>p.name),errors:report.errors,failure:report.failure}));
 }}finally{await browser.close();}
 console.log(out);if(failed)process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1;});
