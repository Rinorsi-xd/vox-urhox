// Original modules in an isolated DOM, without game bootstrap or save writes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8').replace(/^\uFEFF/,''));
const hash=s=>crypto.createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
(async()=>{
 const out=path.join(root,'docs/migration/evidence/source-endless-repair-font-'+new Date().toISOString().replaceAll(':','-'));
 fs.mkdirSync(out,{recursive:true});
 const report={url:'http://localhost:5173/three/',baseline:baseline.commit,sources:[],samples:[],errors:[],
  boundary:'Isolated original EndlessHud and EndlessLoot.supplies DOM/CSS, no game bootstrap, natural enemy wave or save access. CDP actual platform glyph evidence on this Windows Chrome only; not target glyph/mobile acceptance.'};
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:1});
  page.on('pageerror',e=>report.errors.push(e.message));
  await page.route('**/three/src/main.js',r=>r.abort());
  await page.goto(report.url,{waitUntil:'domcontentloaded'});
  for(const relative of ['three/src/battle/endlessLoot.js','shared/ui/endlessHud.js','shared/css/style.css']){
   const response=await page.request.get(new URL('/'+relative,report.url).href);const text=await response.text();
   const frozen=fs.readFileSync(path.resolve(root,baseline.snapshot,relative),'utf8');
   const item={relative,status:response.status(),sha256:hash(text),frozen:hash(frozen),sameAsFrozen:hash(text)===hash(frozen)};
   report.sources.push(item);if(!item.sameAsFrozen)throw Error('Served source differs from frozen baseline: '+relative);
  }
  await page.evaluate(async()=>{
   const {EndlessHud}=await import('/shared/ui/endlessHud.js');
   const {EndlessLoot}=await import('/three/src/battle/endlessLoot.js');
   const {supplyChoices}=await import('/shared/battle/endlessInventory.js');
   const hud=new EndlessHud({next(){}});hud.start();
   const choices=supplyChoices(1,()=>.5);
   window.repairSourceChoices=choices;
   const run={wave:1,tier:1,state:'rest',lives:3,credits:0,score:0,supplies:choices,shield:{hp:100,max:100}};
   hud.update(run);const session={hud,run,drive:{ui:{thumbs:{}}},events(){}};
   const loot=new EndlessLoot(session);loot.supplies();
   for(const el of [...document.body.children])if(el!==hud.root&&el.tagName!=='SCRIPT'&&el.tagName!=='STYLE')el.style.display='none';
   window.repairSourceFixture={hud,loot,run};
  });
  await page.evaluate(()=>document.fonts.ready);
  const cdp=await page.context().newCDPSession(page);await cdp.send('DOM.enable');await cdp.send('CSS.enable');
  await cdp.send('DOM.getDocument');
  for(const [name,width,height]of[['pc',1920,1080],['20x9',840,378]]){
   await page.setViewportSize({width,height});await page.evaluate(()=>document.fonts.ready);
   const computed=await page.locator('.eh-supplies button span').first().evaluate(el=>{
    const c=getComputedStyle(el),r=el.getBoundingClientRect();const range=document.createRange();range.selectNodeContents(el);const ink=range.getBoundingClientRect();
    return {text:el.textContent,fontFamily:c.fontFamily,fontSize:c.fontSize,fontWeight:c.fontWeight,fontStyle:c.fontStyle,
     lineHeight:c.lineHeight,rect:[r.x,r.y,r.width,r.height],glyphRect:[ink.x,ink.y,ink.width,ink.height],
     center:{x:Math.floor(ink.x+ink.width/2),y:Math.floor(ink.y+ink.height/2)},choices:window.repairSourceChoices};
   });
   const located=await cdp.send('DOM.getNodeForLocation',{...computed.center,includeUserAgentShadowDOM:true});
   if(!located.nodeId){const pushed=await cdp.send('DOM.pushNodesByBackendIdsToFrontend',{backendNodeIds:[located.backendNodeId]});located.nodeId=pushed.nodeIds[0];}
   const resolved=await cdp.send('DOM.describeNode',{nodeId:located.nodeId});
   const fonts=await cdp.send('CSS.getPlatformFontsForNode',{nodeId:located.nodeId});
   const {root:documentNode}=await cdp.send('DOM.getDocument');
   const {nodeId}=await cdp.send('DOM.querySelector',{nodeId:documentNode.nodeId,selector:'.eh-supplies button span'});
   const exactFonts=await cdp.send('CSS.getPlatformFontsForNode',{nodeId});
   const screenshot=path.join(out,name+'.png');await page.screenshot({path:screenshot});
   report.samples.push({name,viewport:{width,height},computed,located,node:resolved.node,fonts,exactSpanNodeId:nodeId,exactFonts,screenshot});
  }
  report.result='CAPTURED';
 }catch(error){report.result='FAIL';report.failure=error.stack;process.exitCode=1;}
 finally{await browser.close();report.browserClosed=true;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({out,...report},null,2));}
})().catch(error=>{console.error(error);process.exitCode=1;});
