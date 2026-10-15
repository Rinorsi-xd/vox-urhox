const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(out,'../outgame-baseline.json')));
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const {cornerParts}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/build/selectionTools.js')));
 const {Blueprint}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/build/blueprint.js')));
 const {Editor}=await import(pathToFileURL(path.join(baseline.snapshot,'shared/build/editor.js')));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={commit:baseline.commit,buildDirectory:prepared.source_directory,manifest:prepared.manifest_path,cases:{},passed:false};
 try{
  for(const [name,width,height] of [['pc',1920,1080],['pc-16-10',1440,900]]){
   const page=await browser.newPage({viewport:{width,height}});let state;const errors=[],httpErrors=[];
   const item=report.cases[name]={viewport:[width,height],errors,httpErrors};
   page.on('console',m=>{const t=m.text(),i=t.indexOf('OUTGAME_STATE ');if(i>=0)state=JSON.parse(t.slice(i+14));
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))errors.push(t);
   });page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)httpErrors.push({status:r.status(),url:r.url()});});
   async function wait(fn){const start=Date.now();while(!state||!fn(state)){if(errors.length)throw Error(errors.join('\n'));if(Date.now()-start>120000)throw Error(name+' selection timeout');await delay(100);}}
   async function dump(){await page.keyboard.press('F8');await delay(300);assert.equal(errors.length,0);return structuredClone(state);}
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar');
   await dump();const r=state.homeRects.edit;await page.mouse.click((r[0]+r[2]/2)*width/state.width,(r[1]+r[3]/2)*height/state.height);await wait(s=>s.build);
   let mouseX=width/2,mouseY=height*.4;await page.mouse.click(mouseX,mouseY);await delay(600);await page.keyboard.press('q');
   item.initial=await dump();assert.equal(state.buildInput.captured,true);assert.equal(state.buildSelection.active,true);assert.ok(state.buildSelection.hit?.id);
   await page.mouse.down();await delay(100);item.press=await dump();assert.ok(state.buildSelection.drag);
   const anchor=state.buildSelection.drag.anchor;
   for(let i=0;i<36;i++){
    mouseX-=5;mouseY-=1;await page.mouse.move(mouseX,mouseY,{steps:2});await delay(60);await dump();
    if(state.buildSelection.drag?.pending>0&&state.buildSelection.hit?.id!==item.press.buildSelection.hit.id)break;
   }
   item.drag=await dump();assert.ok(state.buildSelection.drag.pending>0,'real mouse look reaches a second occupied cell');
   const bp=new Blueprint();for(const p of state.buildSelection.parts)bp.add(p);
   const source=Object.create(Editor.prototype);source.bp=bp;source.mirror=state.buildSelection.mirror;
   const expected=[...new Set([...item.press.buildSelection.ids,...source._withGroups(cornerParts(bp,anchor,state.buildSelection.hit.cell)).map(p=>p.id)])].sort((a,b)=>a-b);
   assert.equal(state.buildSelection.drag.pending,expected.length-item.press.buildSelection.ids.length,'pending count matches original H5');
   const png=await page.screenshot({path:path.join(out,'build-selection-web-'+name+'.png')});
   const stats=await sharp(png).stats();assert.ok(stats.channels.some(c=>c.stdev>15),'nonblank selection view');
   assert.ok(JSON.stringify(state.buildSelection.hover).includes('框选'),'actual source drag feedback rendered');
   await page.mouse.up();await delay(150);item.release=await dump();assert.equal(state.buildSelection.drag,false);assert.deepEqual(state.buildSelection.ids,expected);
   const target=state.buildSelection.hit.id;await page.mouse.down({button:'right'});await delay(120);item.deselect=await dump();
   assert.ok(!state.buildSelection.ids.includes(target),'right hold removes selection');assert.equal(state.parts,item.initial.parts);assert.equal(state.buildSelection.revision,item.initial.buildSelection.revision);
   await page.mouse.up({button:'right'});await page.mouse.down();await delay(100);await dump();assert.ok(state.buildSelection.drag,'deselected cell starts another drag');
   await page.keyboard.press('Escape');await page.mouse.up();await delay(150);item.cancel=await dump();
   assert.equal(state.buildSelection.drag,false);assert.equal(state.buildInput.captured,false);assert.equal(state.dialog,false);
   assert.equal(state.parts,item.initial.parts);assert.equal(state.buildSelection.revision,item.initial.buildSelection.revision);
   item.passed=true;console.log('Web original selection parity PASS '+name);await page.close();
  }
  report.passed=true;
 }catch(e){report.failure=e.message;throw e;}
 finally{fs.writeFileSync(path.join(out,'build-selection-web.json'),JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
