// Fixed source station and time, with projection checks independent of screenshot appearance.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'docs/migration/evidence');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const prepared=JSON.parse(fs.readFileSync(path.join(root,'.tmp/outgame-prepare-cached.json')));
const cases=[['pc',1920,1080],['pc-16-10',1440,900],['phone-landscape',840,378],['phone-16-9',800,450],['tablet',1024,768]];
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css','.json':'application/json','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=d3d11']});
 const report={baseline:{branch:baseline.branch,commit:baseline.commit},build:prepared.source_directory,time:10,cases:[]};
 try{
  for(const [name,width,height] of cases.filter(t=>!process.env.VOX_QA_CASE||process.env.VOX_QA_CASE.split(',').includes(t[0]))){
   const touch=name.startsWith('phone')||name==='tablet',options={viewport:{width,height},deviceScaleFactor:touch?3:1,hasTouch:touch,isMobile:touch};
   const page=await browser.newPage(options);
   await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
   await page.waitForFunction(()=>window.__vox,{},{timeout:120000});await page.evaluate(()=>document.fonts.ready);await delay(4000);
   const source=await page.evaluate(async()=>{
    const THREE=await import('/three/vendor/three/build/three.module.js');
    const {updateMaterials}=await import('/three/src/parts/materials.js');
    const v=window.__vox,{rig,garage,editor,camera,pipeline,scene}=v;
    v.shell.debugPreviewActive=true;
    v.shell._station('hangar');rig.autoSpin=false;rig.update(.65);rig.autoSpin=false;
    garage.greet=0;garage.scan.t=-1;garage.scan.mesh.visible=false;
    garage.deckUniforms.uScan.value.z=0;garage.deckUniforms.uFlash.value=0;
    garage.deckUniforms.uGrid.value=garage.gridTarget;garage.deckUniforms.uFrame.value=garage.frameTarget;
    updateMaterials(10);editor.view.update(10);garage.update(0,10,editor,camera);
    scene.updateMatrixWorld();garage.reflection.update(pipeline.renderer,scene,camera);
    for(let i=0;i<3;i++)pipeline.render(1/60,10);
    const anchors=[[0,0,0],[0,3,0],[6,0,0],[-6,0,0],[0,0,6],[0,0,-6]].map(p=>{
     const q=new THREE.Vector3(...p).project(camera);return [(q.x+1)/2,(1-q.y)/2];
    });
    const lights=garage.lights.filter(l=>l.isLight).map(l=>({type:l.type,color:l.color.toArray(),intensity:l.intensity,decay:l.decay,shadow:l.castShadow}));
    return {position:rig.position.toArray(),target:rig.target.toArray(),yaw:180-rig.orbit.cur.theta*180/Math.PI,pitch:90-rig.orbit.cur.phi*180/Math.PI,
     dist:rig.orbit.cur.dist,fov:camera.fov,parts:editor.bp.size,anchors,grid:garage.deckUniforms.uGrid.value,frame:garage.deckUniforms.uFrame.value,
     bounds:editor.bounds,scan:garage.scan.mesh.visible,flash:garage.deckUniforms.uFlash.value,vehicleOffset:editor.view.root.position.toArray(),lights};
   });
   assert.equal(source.scan,false);assert.equal(source.flash,0);
   await page.mouse.move(width-4,height-4);await page.screenshot({path:path.join(out,'hangar-fixed-source-'+name+'.png')});await page.close();
   const targetPage=await browser.newPage(options);let target;const errors=[],httpErrors=[],shaders=[];
   if(process.env.VOX_QA_SHADER_CAPTURE==='1'){
    await targetPage.route('**/UrhoXRuntime.js',async route=>{
     const response=await route.fetch();
     const hook=`for(const name of ['WebGLRenderingContext','WebGL2RenderingContext']){const cls=globalThis[name];if(!cls)continue;const original=cls.prototype.shaderSource;cls.prototype.shaderSource=function(shader,source){if(source.includes('43758'))console.log('VOX_SHADER_CAPTURE '+JSON.stringify(source));return original.call(this,shader,source);};}\n`;
     await route.fulfill({response,body:hook+await response.text()});
    });
   }
   targetPage.on('console',msg=>{const text=msg.text(),i=text.indexOf('OUTGAME_STATE ');if(i>=0){try{target=JSON.parse(text.slice(i+14));}catch(e){errors.push('Incomplete probe: '+e.message);}}
    if(text.startsWith('VOX_SHADER_CAPTURE '))shaders.push(JSON.parse(text.slice(19)));
    if(/ERROR:|Execute Lua|stack traceback|Aborted\(|Shader compilation failed/.test(text))errors.push(text);
   });
   targetPage.on('pageerror',e=>errors.push(e.message));targetPage.on('requestfailed',r=>errors.push(r.url()+' '+r.failure()?.errorText));
   targetPage.on('response',r=>{if(r.status()>=400)httpErrors.push({url:r.url(),status:r.status()});});
   async function wait(predicate,label,timeout=240000){const started=Date.now();while(!target||!predicate(target)){if(Date.now()-started>timeout)throw Error(name+' timeout '+label);await delay(100);}}
   await targetPage.goto('http://127.0.0.1:4204/outgame.html?-game_url=http://127.0.0.1:4204/game-dist/&-log=info&cached=1');
   await wait(s=>s.tab==='hangar','home');await targetPage.keyboard.press('F9',{delay:100});await delay(2000);await targetPage.keyboard.press('F8',{delay:100});
   await wait(s=>s.hangar.time===10&&!s.hangar.scan,'fixed scene');
   const c=target.camera;
   for(const [key,expected] of Object.entries({position:[-source.position[0],source.position[1],source.position[2]],target:[-source.target[0],source.target[1],source.target[2]]})){
    c[key].forEach((value,i)=>assert.ok(Math.abs(value-expected[i])<.0002,key+' '+i+' differs from frozen source'));
   }
   for(const key of ['yaw','pitch','dist','fov'])assert.ok(Math.abs(c[key]-source[key])<.0002,key+' differs from frozen source');
   assert.equal(target.parts,source.parts);assert.ok(Math.abs(target.hangar.grid-source.grid)<.0001);assert.ok(Math.abs(target.hangar.frame-source.frame)<.0001);
   assert.equal(target.hangar.lights.length,source.lights.filter(l=>l.type!=='HemisphereLight').length);
   assert.ok(target.hangar.lights.every(l=>l.name!=='Directional Light'),'Preset light must not reappear');
   assert.equal(target.hangar.lights.filter(l=>l.shadow).length,source.lights.filter(l=>l.shadow).length);
   const pixelErrors=target.anchors.map((p,i)=>Math.hypot((p[0]-source.anchors[i][0])*width,(p[1]-source.anchors[i][1])*height));
   assert.ok(Math.max(...pixelErrors)<.1,'Projected source anchors differ');assert.equal(errors.length,0,errors.join('\n'));
   await targetPage.mouse.move(width-4,height-4);await targetPage.screenshot({path:path.join(out,'hangar-fixed-web-'+name+'.png')});
   if(process.env.VOX_QA_SHADER_CAPTURE==='1')fs.writeFileSync(path.join(out,'hangar-generated-shaders-'+name+'.json'),JSON.stringify([...new Set(shaders)],null,2));
   if(process.env.VOX_QA_LIGHTING==='1'){
    await targetPage.keyboard.press('F10',{delay:100});await delay(1500);await targetPage.keyboard.press('F8',{delay:100});
    await wait(s=>s.hangar.shadows===false,'shadow isolation',10000);
    await targetPage.screenshot({path:path.join(out,'hangar-fixed-web-'+name+'-no-shadows.png')});
    await targetPage.keyboard.press('F10',{delay:100});
   }
   if(process.env.VOX_QA_SURFACE==='1'){
    await targetPage.keyboard.press('F11',{delay:100});await delay(1500);await targetPage.keyboard.press('F8',{delay:100});
    await wait(s=>s.hangar.panelIsolation===true,'panel isolation',10000);
    await targetPage.screenshot({path:path.join(out,'hangar-fixed-web-'+name+'-no-panels.png')});
    await targetPage.keyboard.press('F11',{delay:100});await delay(1500);await targetPage.keyboard.press('F8',{delay:100});
    await wait(s=>s.hangar.panelIsolation===false,'restore panels',10000);
   }
   report.cases.push({name,viewport:[width,height],touch,source,target:c,deck:target.hangar,maxAnchorErrorPixels:Math.max(...pixelErrors),errors,httpErrors,
    limitations:['Moving drones retain runtime history; only source station and shader/arm/crane time are fixed.','Projection and parameter parity do not prove rendered pixel parity.']});
   await targetPage.close();console.log(name+' fixed camera, deck and 6 projections PASS');
  }
  fs.writeFileSync(path.join(out,'hangar-fixed-parity.json'),JSON.stringify(report,null,2));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
