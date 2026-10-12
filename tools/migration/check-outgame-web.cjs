const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const checkStreaming=process.env.VOX_QA_STREAMING==='1';
const preparedFile=process.env.VOX_PREPARE_FILE||(process.env.VOX_QA_CACHED_SOURCES==='1'?'.tmp/outgame-prepare-cached.json':'.tmp/outgame-prepare.json');
const prepared=JSON.parse(fs.readFileSync(path.resolve(root,preparedFile),'utf8').replace(/^\uFEFF/,''));
const mediaByFile=new Map();
if(checkStreaming){
 const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
 for(const file of manifest.files)if(file.fs_path?.startsWith('UI/')&&['.jpg','.png'].includes(file.ext)){
  assert.ok(!(file.groups||[]).includes('boot')||!/^UI\/(Parts|Prefabs|Modes|Salvage|Faces)\//.test(file.fs_path),'Deferred page artwork must not belong to boot');
  mediaByFile.set(file.uuid+'-'+file.hash+file.ext,file.fs_path);
 }
}
const cases=[
 {name:'pc',width:1920,height:1080,dpr:1},
 {name:'phone-landscape',width:840,height:378,dpr:3,touch:true},
 {name:'phone-16-9',width:800,height:450,dpr:3,touch:true},
 {name:'tablet',width:1024,height:768,dpr:2,touch:true},
 {name:'wide',width:2560,height:1080,dpr:1},
];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report=[];const failed=[];
 try{
  for(const test of cases.filter(test=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(test.name))){
   const page=await browser.newPage({viewport:{width:test.width,height:test.height},deviceScaleFactor:test.dpr,...(test.touch?{hasTouch:true,isMobile:true}:{})});
   const context=page.context(),messages=[],errors=[],states=[],mediaResponses=new Set();let current;
   if(process.env.VOX_QA_COLD_CAROUSEL==='1'){
    const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
    const file=manifest.files.find(f=>f.fs_path==='UI/Prefabs/hawk.jpg');
    assert.ok(file,'Cold image check uses the original hawk artwork');
    await page.route('**/'+file.uuid+'-'+file.hash+file.ext,async route=>{await sleep(1500);await route.continue();});
   }
   page.on('response',response=>{
    const file=new URL(response.url()).pathname.split('/').pop();const source=mediaByFile.get(file);
    if(source&&response.ok())mediaResponses.add(source);
   });
   const logFile=path.join(out,'outgame-web-'+test.name+'.log');fs.writeFileSync(logFile,'');
   page.on('console',msg=>{const text=msg.text();messages.push(text);fs.appendFileSync(logFile,text+'\n');const marker=text.indexOf('OUTGAME_STATE ');if(marker>=0){current=JSON.parse(text.slice(marker+14));states.push(current);}if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))errors.push(text);});
   page.on('pageerror',e=>errors.push('PAGEERROR '+e.message));
   page.on('requestfailed',r=>errors.push('NETWORK '+r.url()+' '+r.failure()?.errorText));
   async function wait(predicate,label,timeout=240000){const start=Date.now();while(!current||!predicate(current)){if(Date.now()-start>timeout){await page.screenshot({path:path.join(out,'outgame-web-'+test.name+'-failure.png')});fs.writeFileSync(path.join(out,'outgame-web-'+test.name+'-failure.json'),JSON.stringify({label,current,errors},null,2));throw Error(test.name+' timeout '+label+' '+JSON.stringify(current));}await sleep(100);}return current;}
   async function dump(){const count=states.length;await page.keyboard.down('F8');await sleep(100);await page.keyboard.up('F8');await wait(()=>states.length>count,'UI bounds',10000);return current;}
   async function key(name){await page.keyboard.down(name);await sleep(100);await page.keyboard.up(name);await sleep(100);await dump();}
   async function click(text,icon){
    for(let attempt=0;attempt<10;attempt++){
     const state=await dump();assert.ok(Array.isArray(state.widgets),'Active page must contain a live widget tree');const widget=state.widgets.find(w=>(icon?w.icon===icon:w.text===text)&&!w.disabled);
     if(!widget){await sleep(150);continue;}
     const [x,y,w,h]=widget.rect,canvas=await page.locator('canvas').boundingBox();
     const px=canvas.x+(x+w/2)/state.width*canvas.width,py=canvas.y+(y+h/2)/state.height*canvas.height;
     if(px>=0&&py>=0&&px<test.width&&py<test.height){if(test.touch)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);return;}
     if(test.touch){
      const cdp=await context.newCDPSession(page);const x=test.width*.22;
      const startY=py>=test.height?test.height*.8:test.height*.3,endY=py>=test.height?test.height*.25:test.height*.8;
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y:startY,id:1}]});
      for(let i=1;i<=12;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:startY+(endY-startY)*i/12,id:1}]});await sleep(20);}
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
     }else{await page.mouse.move(test.width*.22,test.height*.5);await page.mouse.wheel(0,py>=test.height?test.height*.65:-test.height*.65);}
     await sleep(350);
    }
    throw Error('Offscreen command '+text);
   }
   async function shot(name){await sleep(1000);await page.screenshot({path:path.join(out,'outgame-web-'+test.name+'-'+name+'.png')});}
   const cached=process.env.VOX_QA_CACHED_SOURCES==='1';
   if(cached&&process.env.VOX_QA_BROWSER_CACHE!=='1'){
    const cache=require('./cached-engine-sources.cjs');
    await page.route('https://tapcode-sce.spark.xd.com/**',async route=>{
     const resource=cache.read(route.request().url());
     await route.fulfill(resource?{body:resource.body,headers:{'content-type':resource.headers['content-type']||'application/octet-stream','access-control-allow-origin':'*','cross-origin-resource-policy':'cross-origin'}}:{status:404,body:''});
    });
   }
   await page.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info'+(process.env.VOX_QA_BROWSER_CACHE==='1'?'&cached=1':''));
   await wait(s=>s.tab==='hangar','home');await sleep(4000);await shot('home');const home=current;
   const startupMedia=[...mediaResponses];
   if(checkStreaming)assert.ok(!startupMedia.some(path=>/^UI\/(Prefabs|Modes|Faces)\//.test(path)),'Unopened page artwork must not download before home');
   const gpu=await page.evaluate(()=>{const g=document.querySelector('canvas').getContext('webgl2'),e=g?.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):'unknown'});
   await click('创意工坊');await wait(s=>s.tab==='workshop','workshop');await shot('workshop');
   await dump();assert.equal(current.sceneVisible,false,'Opaque featured page suspends the hidden hall viewport');
   if(checkStreaming)assert.ok(mediaResponses.has('UI/Prefabs/scorpion.jpg'),'Featured artwork must download when opening workshop');
   if(process.env.VOX_QA_CAROUSEL==='1'){
    await click('隼');await dump();
    if(process.env.VOX_QA_COLD_CAROUSEL==='1'){
     assert.equal(current.workshop.pending,'hawk');
     assert.equal(current.workshop.selected,'scorpion','Delayed original image preserves the old matching caption');
     assert.equal(current.workshop.slides.scorpion.alpha.value,1);
     assert.equal(current.workshop.slides.hawk.alpha.value,0,'Placeholder cannot start the source crossfade');
     await page.screenshot({path:path.join(out,'outgame-web-'+test.name+'-carousel-cold.png')});
    }
    await wait(s=>s.workshop?.selected==='hawk'&&s.workshop?.imagesReady?.hawk,'original incoming picture ready');
    await dump();
    const fading=current.workshop.slides;
    assert.ok(fading.scorpion.alpha.value>0&&fading.scorpion.alpha.value<1&&fading.hawk.alpha.value>0&&fading.hawk.alpha.value<1,'Source recommendation crossfade remains visible after UI rebuild');
    await page.screenshot({path:path.join(out,'outgame-web-'+test.name+'-carousel-fade.png')});
    await click('赤焰 GT');await wait(s=>s.workshop?.selected==='raceCar','racer image ready');await sleep(1100);await dump();
    assert.equal(current.workshop.selected,'raceCar');
    assert.equal(current.workshop.slides.scorpion.alpha.value,0);
    assert.equal(current.workshop.slides.hawk.alpha.value,0);
    assert.equal(current.workshop.slides.raceCar.alpha.value,1);
    await shot('carousel-settled');
    await click('蝎型战车');await wait(s=>s.workshop?.selected==='scorpion','scorpion image ready');await sleep(1000);await dump();
    assert.equal(current.workshop.slides.scorpion.alpha.value,1);
   }
   if(test.touch)await click('查看详情');else await key('Enter');
   await wait(s=>s.workshop?.view==='detail'&&s.preview?.complete,'cold 3D preview');await shot('detail');
   assert.equal(current.sceneVisible,true,'Detail restores the authored hall');
   if(!test.touch){
    await key('ArrowRight');await wait(s=>s.workshop?.selected==='fox'&&s.preview?.complete,'source right arrow');
    await key('ArrowLeft');await wait(s=>s.workshop?.selected==='scorpion'&&s.preview?.complete,'source left arrow');
    await key('Backspace');await wait(s=>s.workshop?.view==='feature','source detail backspace');
    await key('Enter');await wait(s=>s.workshop?.view==='detail'&&s.preview?.complete,'source Enter reopens preview');
   }
   await click('返回');await wait(s=>s.workshop?.view==='feature','return to original feature entry');
   await click('查看全部');await wait(s=>s.workshop?.view==='browse','browse');
   await shot('browse');
   await dump();assert.equal(current.sceneVisible,true,'Translucent source browse retains its hall background');
   if(!test.touch){
    const before=await dump(),card=before.widgets.find(w=>w.text==='赤焰 GT'&&w.card);
    assert.ok(card,'Source workshop card supports native hover');
    const [x,y,w,h]=card.rect,canvas=await page.locator('canvas').boundingBox();
    await page.mouse.move(canvas.x+(x+w*.7)/before.width*canvas.width,canvas.y+(y+h*.7)/before.height*canvas.height);
    await sleep(900);await dump();
    const hovered=current.widgets.find(w=>w.text==='赤焰 GT'&&w.card);
    assert.ok(hovered.card.hovered&&hovered.card.image>.99&&hovered.card.reveal>.99&&hovered.card.opacity>.99,'Hover zoom, source bars and view command settle');
    await shot('browse-hover');
    await page.mouse.move(test.width-8,test.height-8);await sleep(700);await dump();
    const restored=current.widgets.find(w=>w.text==='赤焰 GT'&&w.card);
    assert.ok(!restored.card.hovered&&restored.card.image<.01&&restored.card.reveal<.01,'Leaving restores frozen card without rebuilding page');
   }
   await click('轮式');await dump();assert.equal(current.workshop.group,'wheel');await shot('filter');
   await click('机库');await wait(s=>s.tab==='hangar','return');
   await click('改装');await wait(s=>s.build,'builder');await shot('builder');
   await dump();assert.ok(current.widgets.some(w=>w.text==='赛车红'),'Frozen default paint color');
   const help=current.widgets.find(w=>w.icon==='help');assert.ok(help,'Original build help button');
   assert.ok(Math.abs(help.rect[0]-(current.width-393))<1,'Original toolbar placement');
   const swatches=current.widgets.filter(w=>w.kind==='dock-swatch');
   assert.equal(swatches.length,17,'Original nonoverlapping 20px palette cells');
   const pixel=current.width/current.physical[0];
   for(const cell of swatches){
    assert.equal(cell.styleWidth,20);assert.equal(cell.styleHeight,20);
    assert.ok(Math.abs(cell.rect[2]-20)<=pixel+.001&&Math.abs(cell.rect[3]-20)<=pixel+.001,'Palette retains source size after physical-pixel snapping');
    const next=swatches.find(other=>Math.abs(other.rect[1]-cell.rect[1])<.001&&other.rect[0]>cell.rect[0]+.001);
    if(next)assert.ok(next.rect[0]>=cell.rect[0]+cell.rect[2]-.001,'Palette cells do not overlap');
   }
   await click('','help');await wait(s=>s.dialog,'build help');await shot('build-help');
   await page.keyboard.press('h');await wait(s=>!s.dialog,'H closes help without reopening',10000);
   if(test.touch){
    await dump();const slot=current.widgets.find(w=>w.part&&w.rect[1]>current.height*.8);assert.ok(slot,'Original hotbar is available for touch inventory access');
    const [x,y,w,h]=slot.rect,canvas=await page.locator('canvas').boundingBox();
    const px=canvas.x+(x+w/2)/current.width*canvas.width,py=canvas.y+(y+h/2)/current.height*canvas.height;
    const cdp=await context.newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:px,y:py,id:1}]});await sleep(900);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
   }else await page.keyboard.press('b');
   await wait(s=>s.inventory,'inventory');await shot('inventory');
   await click('更多参数');await shot('inventory-expanded');
   await click('操作说明');await shot('inventory-help');await click('操作说明');
   await click('关闭');await wait(s=>!s.inventory,'inventory close');
   await click('机库');await wait(s=>!s.build&&s.tab==='hangar','builder close');
   if(process.env.VOX_QA_EXTENDED==='1'){
    await click('商店');await wait(s=>s.tab==='shop','shop');await shot('shop');
    await click('机库');await wait(s=>s.tab==='hangar','shop return');
    await click('出战');await wait(s=>s.tab==='battle','mode page');await shot('modes');
    await click('站点争夺');await dump();assert.equal(current.modeChoice,'conquest');
    await click('剧情模式');await wait(s=>s.tab==='story'&&s.story?.ready,'3D story page');await shot('story');
    assert.equal(current.sceneVisible,false,'Opaque story page pauses hidden 3D rendering');
    if(!test.touch){
     const before=await dump(),x=test.width*.47,y=test.height*.48;
     await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+100,y+30,{steps:10});await page.mouse.up();await sleep(500);await dump();
     assert.ok(Math.abs(current.story.az-before.story.az)>.05,'Story table drag changes view');
     const zoom=current.story.zoom;await page.mouse.wheel(0,-200);await sleep(500);await dump();
     assert.ok(Math.abs(current.story.zoom-zoom)>.01,'Story table wheel changes zoom');
     await page.mouse.dblclick(x,y);await sleep(600);await dump();assert.ok(Math.abs(current.story.zoom-1)<.01,'Story table double click resets zoom');
    }
    await click('02  物资车');await dump();assert.equal(current.storyLevel,2);
    await click('选择模式');await wait(s=>s.tab==='battle','mode return');
    await click('机库');await wait(s=>s.tab==='hangar','home');
    await click('打捞行动');await wait(s=>s.tab==='salvage'&&s.lobby==='salvage'&&s.warehouse?.ready,'salvage');await shot('salvage');
    assert.equal(current.warehouse.hallVisible,false,'Warehouse hides original hangar');
    await click('仓库');await dump();assert.equal(current.salvage.stash,true);await shot('stash');
    await click('数量');await dump();assert.equal(current.salvage.sort,'count');
    await click('收起仓库');await dump();assert.equal(current.salvage.stash,false);
    await click('行动');await wait(s=>s.salvage?.tab==='ops','ops');await shot('ops');
    await click('商人');await wait(s=>s.salvage?.tab==='market','market');await shot('market');
    await dump();const item=current.widgets.find(w=>w.rect[0]>=78&&w.rect[0]<780&&w.rect[1]>=266&&w.rect[1]<700&&!w.disabled);
    assert.ok(item,'Market has a selectable source item');await click(item.text);await dump();assert.ok(current.salvage.selected,'Market selection populates source detail');await shot('market-selected');
    await click('车库');await wait(s=>s.salvage?.tab==='garage','garage');await shot('garage');
    await click('竞技对战');await wait(s=>s.tab==='hangar'&&s.lobby==='arena','arena restored');
    assert.equal(current.sceneVisible,true,'Returning restores the authored 3D scene');
    if(process.env.VOX_QA_MAPS==='1'){
     await click('出战');await wait(s=>s.tab==='battle','map mode page');
     for(const [choice,map] of [['试车场','trial'],['自由探索','crater']]){
      await click(choice);await page.keyboard.press('F6');await wait(s=>s.mapPreview&&s.previewMap===map,map+' presentation');
      await sleep(map==='crater'?6000:2000);await shot('map-'+map);
      await click('拉远');await shot('map-'+map+'-zoom');
      await click('返回');await wait(s=>!s.mapPreview&&s.tab==='battle',map+' return');
     }
     await click('机库');await wait(s=>s.tab==='hangar','maps return');
    }
   }
   if(!test.touch){
    await click('创意工坊');await wait(s=>s.tab==='workshop','workshop key acceptance');
    if(current.workshop.view==='browse'){await click('返回');await wait(s=>s.workshop?.view==='feature','feature entry');}
    await key('Enter');await wait(s=>s.workshop?.view==='detail'&&s.preview?.complete,'detail for add');
    const prefabs=JSON.parse(fs.readFileSync(path.join(root,'assets/UI/Workshop.json'),'utf8')).prefabs;
    for(let i=0;i<prefabs.length&&current.workshop.selected!=='raceCar';i++){
     const index=prefabs.findIndex(p=>p.id===current.workshop.selected),next=prefabs[(index+1)%prefabs.length].id;
     await key('ArrowRight');await wait(s=>s.workshop?.selected===next&&s.preview?.complete,'source next vehicle '+next);
    }
    assert.equal(current.workshop.selected,'raceCar');
    await key('Enter');await wait(s=>s.tab==='hangar'&&s.blueprint==='赤焰 GT','source Enter adds selected vehicle');
    assert.equal(current.build,false,'Workshop Enter adds a garage slot without entering the builder');
    await click('创意工坊');await wait(s=>s.tab==='workshop'&&s.workshop?.view==='browse','Leaving detail restores browse on reentry');
    await click('机库');await wait(s=>s.tab==='hangar','key acceptance returns home');
   }
   await sleep(5000);await dump();
   const result={...test,gpu,build:{directory:path.basename(prepared.source_directory),manifest:path.basename(prepared.manifest_path)},engineSources:cached?{mode:'downloaded-snapshots',snapshots:require('./cached-engine-sources.cjs').snapshots}:{mode:'live-cdn'},home:{width:home.width,height:home.height,physical:home.physical,render:home.render,touch:home.touch},frames:current.frames,errors,states,...(checkStreaming?{streaming:{startupMedia,visitedPageMedia:[...mediaResponses]}}:{})};
   report.push(result);fs.writeFileSync(path.join(out,'outgame-web-'+test.name+'.log'),messages.join('\n'));
   fs.writeFileSync(path.join(out,'outgame-web-'+test.name+'.json'),JSON.stringify(result,null,2));
   if(errors.length)failed.push(test.name+': '+errors.length+' runtime errors');
   console.log((errors.length?'FAIL ':'PASS ')+test.name+' '+JSON.stringify(result.home)+' frame pacing '+JSON.stringify(current.frames));
   await context.close();
  }
  assert.equal(failed.length,0,failed.join('\n'));
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
