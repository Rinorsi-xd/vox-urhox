// Same-camera visual evidence from the untouched Three.js source.
const fs=require('fs'),path=require('path'),http=require('http');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const source=path.resolve(process.argv[2]||'D:/Rino_Project/Vox');
const output=path.resolve(__dirname,'../../docs/migration/evidence');
(async()=>{
 const server=http.createServer((req,res)=>{
  const file=path.resolve(source,'.'+decodeURIComponent(new URL(req.url,'http://local').pathname));
  if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory())return res.writeHead(404).end();
  res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.css':'text/css'})[path.extname(file)]||'application/octet-stream');
  fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try {
  const page=await browser.newPage({viewport:{width:2040,height:1080}});
  await page.goto('http://127.0.0.1:'+server.address().port+'/three/index.html');
  await page.waitForFunction(()=>window.__vox,{timeout:180000});
  await page.evaluate(()=>{window.requestAnimationFrame=()=>0;});
  await page.waitForTimeout(200);
  await page.addStyleTag({content:'body > *:not(#app){visibility:hidden} canvas{visibility:visible!important} #app *:not(canvas){visibility:hidden}'});
  for(const [name,target,dist,yaw,pitch] of [['hall',[0,5,-8],32,180,12],['door',[0,10,-70],41,180,0],['rear',[0,12,20],38,0,0]]){
   await page.evaluate(async ({target,dist,yaw,pitch})=>{
    const v=window.__vox,T=await import('/three/vendor/three/build/three.module.js');
    const {sharedTime}=await import('/three/src/parts/materials.js');
    const a=yaw*Math.PI/180,b=pitch*Math.PI/180;
    v.camera.position.set(-target[0]+Math.sin(a)*Math.cos(b)*dist,target[1]+Math.sin(b)*dist,target[2]-Math.cos(a)*Math.cos(b)*dist);
    v.camera.lookAt(-target[0],target[1],target[2]);v.camera.fov=65;v.camera.updateProjectionMatrix();v.camera.updateMatrixWorld(true);
    sharedTime.value=10;v.editor.garage.greet=0;v.editor.garage.scan.t=-1;v.editor.garage.scan.mesh.visible=false;
    v.editor.garage.update(0,10,v.editor,v.camera);
    v.editor.garage.reflection.update(v.pipeline.renderer,v.scene,v.camera);
    v.pipeline.render(1/60,10);
   },{target,dist,yaw,pitch});
   const png=await page.evaluate(()=>window.__vox.pipeline.renderer.domElement.toDataURL('image/png'));
   fs.writeFileSync(path.join(output,'h5-'+name+'.png'),Buffer.from(png.split(',')[1],'base64'));
  }
  console.log('Captured original H5 hall, door and rear');
 }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exit(1)});
