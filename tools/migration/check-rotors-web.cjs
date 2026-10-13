const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={build:prepared.source_directory,manifest:prepared.manifest_path,errors:[],httpErrors:[],checks:0,passed:false};
 let state;
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});
  const log=path.join(out,'rotors-web-pc.log');fs.writeFileSync(log,'');
  page.on('console',m=>{const t=m.text(),i=t.indexOf('OUTGAME_STATE ');fs.appendFileSync(log,t+'\n');if(i>=0){try{state=JSON.parse(t.slice(i+14));}catch(e){report.probeIssues=(report.probeIssues||[]).concat(e.message);}}
   if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))report.errors.push(t);});
  page.on('pageerror',e=>report.errors.push(e.message));
  page.on('response',r=>{if(r.status()>=400)report.httpErrors.push({status:r.status(),url:r.url()});});
  const check=(value,name)=>{assert.ok(value,name);report.checks++;};
  async function wait(fn){const start=Date.now();while(!state||!fn(state)){if(report.errors.length)throw Error(report.errors.join('\n'));if(Date.now()-start>150000)throw Error('Rotor Web state timeout');await delay(100);}}
  async function dump(){await page.keyboard.press('F8');await delay(400);check(report.errors.length===0,'no unexpected runtime errors');return structuredClone(state);}
  async function key(k){await page.keyboard.down(k);await delay(100);await page.keyboard.up(k);await delay(200);await dump();}
  async function shot(name){const png=await page.screenshot({path:path.join(out,'rotors-web-pc-'+name+'.png')});check((await sharp(png).stats()).channels.some(c=>c.stdev>15),'visible rendered '+name);}
  await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar');await dump();
  await key('Insert');await wait(s=>s.build&&s.parts===6);await dump();
  check(state.parts===6,'fixture model gate permits actual blueprint load');
  await page.mouse.move(960,540);await page.mouse.down();await delay(120);await page.mouse.up();await delay(600);await dump();
  check(state.buildInput.captured,'actual PC build mouse capture');
  check(state.buildSelection.hit?.id===2&&state.rotorHud.visible&&state.rotorHud.mode===3,'actual ray targets authored step turntable');
  check(state.rotorHud.load===4,'source HUD identifies joined blocks and weapon as load');await shot('step-hud');
  await key('2');check(state.rotorHud.mode===2,'real 2 key changes to continuous spin');await shot('spin-hud');
  await key('3');check(state.rotorHud.mode===3,'real 3 key changes to ninety-degree step');
  await page.keyboard.down('Control');await key('z');await page.keyboard.up('Control');check(state.rotorHud.mode===2,'real undo restores previous mode');
  await page.keyboard.down('Control');await key('y');await page.keyboard.up('Control');check(state.rotorHud.mode===3,'real redo restores step mode');
  await key('t');await wait(s=>s.mode==='trial'&&!s.loadingFlow.active);await dump();
  check(state.rotors.length===1&&state.rotors[0].mode==='step','production trial retains selected mode');
  await page.mouse.click(960,540);await delay(500);await dump();check(state.pointer.captured,'actual trial mouse capture');await shot('before');
  const target=state.rotors[0].target;await key('f');await delay(600);await dump();
  check(Math.abs(state.rotors[0].target-target-Math.PI/2)<1e-6,'actual F advances target exactly ninety degrees');
  check(Math.abs(state.rotors[0].angle-state.rotors[0].target)<.01,'visible load reaches stepped pose');await shot('after');
  await delay(500);await dump();check(Math.abs(state.rotors[0].target-target-Math.PI/2)<1e-6,'released F does not repeat on fixed ticks');
  await key('Escape');await key('t');await wait(s=>s.mode==='hangar'&&!s.loadingFlow.active);await dump();
  check(state.build&&state.parts===6&&!state.buildInput.captured&&!state.mouse.overlay,'return restores authored build and releases trial capture and overlays');
  report.final=state;report.passed=true;
 }catch(e){report.failure=e.message;report.failureState=state;throw e;}
 finally{fs.writeFileSync(path.join(out,'rotors-web-pc.json'),JSON.stringify(report,null,2));await browser.close();}
 console.log('Web rotors PASS '+report.checks);
})().catch(e=>{console.error(e);process.exitCode=1;});
