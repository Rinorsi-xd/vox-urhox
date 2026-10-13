const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const {pathToFileURL}=require('node:url');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const load=name=>import(pathToFileURL(path.join(baseline.snapshot,'shared',name)));
 const [{PARTS},{ROTATIONS},{exactShapeGeo},{faceMask},{getInstancedLayers},THREE]=await Promise.all([
  load('parts/defs.js'),load('core/rotations.js'),load('parts/shapes.js'),load('parts/solid.js'),load('parts/models.js'),
  import(pathToFileURL(path.join(baseline.snapshot,'three/vendor/three/build/three.module.js')))]);
 const code=fs.readFileSync(path.join(baseline.snapshot,'three/src/build/vehicleView.js'),'utf8');
 const JOINED=Object.fromEntries(['paint','heavyPaint','glassPaint','neonPaint'].map(s=>[s,new THREE.MeshBasicMaterial({vertexColors:true})]));
 const Joined=vm.runInNewContext(code.slice(code.indexOf('class JoinedMesh {'),code.indexOf('class InstancedBatch {'))+';JoinedMesh',
  {THREE,PARTS,ROTATIONS,exactShapeGeo,faceMask,getInstancedLayers,JOINED,_jc:new THREE.Color()});
 function sourceVertices(parts){const mesh=new Joined(new THREE.Group());for(const p of parts)if(p.g&&PARTS[p.type].shape&&!PARTS[p.type].panel)mesh.add(p);mesh.update();
  const count=[...mesh.meshes.values()].reduce((n,m)=>n+m.geometry.attributes.position.count,0);mesh.clear();return count;}
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={commit:baseline.commit,buildDirectory:prepared.source_directory,manifest:prepared.manifest_path,cases:{},passed:false};
 try{
  for(const [name,width,height,touch] of [['pc',1920,1080,false],['phone-landscape',840,378,true],['tablet',1024,768,true]].filter(c=>!process.env.VOX_GROUPS_CASE||c[0]===process.env.VOX_GROUPS_CASE)){
   const page=await browser.newPage({viewport:{width,height},hasTouch:touch,deviceScaleFactor:touch?2:1});let state;
   const errors=[],httpErrors=[],item=report.cases[name]={viewport:[width,height],errors,httpErrors,checks:0};
   page.on('console',m=>{const t=m.text(),i=t.indexOf('OUTGAME_STATE ');if(i>=0)state=JSON.parse(t.slice(i+14));if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(t))errors.push(t);});
   page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)httpErrors.push({status:r.status(),url:r.url()});});
   async function wait(fn){const start=Date.now();while(!state||!fn(state)){if(errors.length)throw Error(errors.join('\n'));if(Date.now()-start>120000)throw Error(name+' groups timeout');await delay(100);}}
   async function dump(){await page.keyboard.press('F8');await delay(350);assert.equal(errors.length,0);return structuredClone(state);}
   function check(v,msg){if(!v)item.failureState=structuredClone(state);assert.ok(v,msg);item.checks++;}
   async function chord(k){await page.keyboard.down('Control');await page.keyboard.down(k);await delay(150);await page.keyboard.up(k);await page.keyboard.up('Control');await delay(150);await dump();}
   async function key(k){await page.keyboard.down(k);await delay(100);await page.keyboard.up(k);await delay(120);await dump();}
   async function clickRect(r){const x=(r[0]+r[2]/2)*width/state.width,y=(r[1]+r[3]/2)*height/state.height;if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await delay(200);await dump();}
   async function command(text,keyName){if(touch){const b=state.widgets.find(w=>w.text===text);check(b,'source '+text+' control present');await clickRect(b.rect);}else await key(keyName);}
   async function shot(suffix){const png=await page.screenshot({path:path.join(out,`build-groups-web-${name}-${suffix}.png`)});check((await sharp(png).stats()).channels.some(c=>c.stdev>15),'rendered nonblank '+suffix);}
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');await wait(s=>s.tab==='hangar');await dump();
   await clickRect(state.homeRects.edit);await wait(s=>s.build);await dump();
   console.log(name+' build ready');
   if(!touch){await page.mouse.move(width*.5,height*.4);await page.mouse.down();await delay(120);await page.mouse.up();await delay(600);await dump();check(state.buildInput.captured,'actual PC mouse capture');}
   await command('选择','q');await chord('a');check(state.buildSelection.ids.length===state.parts,'actual Ctrl+A selects entire authored vehicle');
   item.before=await dump();const revision=state.buildSelection.revision,count=state.parts;
   await command('连块','f');item.joined=await dump();
   console.log(name+' F joined');
   check(Object.keys(state.buildGroups.parts).length>0&&state.buildGroups.vertices>0,'source F creates real joined surfaces');
   check(state.buildSelection.revision===revision+1&&state.parts===count,'joining is one edit without changing cells');
   check(state.buildGroups.vertices===sourceVertices(state.buildSelection.parts),'displayed exterior vertex count matches frozen H5 JoinedMesh');
   await shot('joined');const groups=JSON.stringify(state.buildGroups.parts),vertices=state.buildGroups.vertices;
   const builds=state.buildGroups.rebuilds;await delay(1000);await dump();check(state.buildGroups.rebuilds===builds,'idle group renderer uploads no new geometry');
   await chord('z');check(JSON.stringify(state.buildGroups.parts)===JSON.stringify(item.before.buildGroups.parts),'one Ctrl+Z restores original groups');
   await chord('y');check(JSON.stringify(state.buildGroups.parts)===groups&&state.buildGroups.vertices===vertices,'one Ctrl+Y restores complete joined surfaces');
   await command('透视','v');check(state.buildGroups.xray,'actual source xray control');await shot('xray');await command('透视','v');
   await command('连块','f');check(Object.keys(state.buildGroups.parts).length===0&&state.buildGroups.vertices===0,'second F releases joined geometry and returns ordinary blocks');
   await chord('z');check(state.buildGroups.vertices===vertices,'undo split restores joined vehicle');
   await chord('y');check(state.buildGroups.vertices===0,'redo split retires joined vehicle');
   // Clear selection through the production escape path before toggling joined placement.
   await key('Escape');if(state.buildSelection.ids.length)await key('Escape');
   await command('连块','f');check(state.buildGroups.joinNew,'F without selection toggles joined placement');
   await command('连块','f');check(!state.buildGroups.joinNew,'second F resets placement mode');
   item.final=await dump();check(state.parts===count&&!state.buildGroups.xray,'flow leaves vehicle cells and xray state intact');
   item.passed=true;console.log('Web groups PASS '+name+' '+item.checks);await page.close();
  }
  report.passed=true;
 }catch(e){report.failure=e.message;throw e;}finally{fs.writeFileSync(path.join(out,'build-groups-web.json'),JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
