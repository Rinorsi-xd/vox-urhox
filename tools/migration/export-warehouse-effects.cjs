// Recover dynamic material identity and original particle seeds without rebaking geometry.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url==='/migration.html'){res.setHeader('Content-Type','text/html');res.end('<script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","three/addons/":"/three/vendor/three/addons/","@shared/":"/shared/"}}</script>');return;}
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(req.url.split('?')[0]));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'application/octet-stream');fs.createReadStream(file).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  const page=await browser.newPage();await page.goto('http://127.0.0.1:'+server.address().port+'/migration.html');
  const result=await page.evaluate(async()=>{
   const T=await import('three'),{Warehouse}=await import('/three/src/scene/warehouse.js');
   const wh=new Warehouse(new T.Scene());wh.setActive(true);wh.update(0,0);wh.deck.top.material.name='WarehouseDeck';
   const ids=new Map(),materials=[];
   wh.group.traverse(o=>{if(!o.isMesh)return;for(let p=o;p;p=p.parent)if(!p.visible)return;for(const m of Array.isArray(o.material)?o.material:[o.material]){
    if(m.visible===false||ids.has(m.uuid))continue;ids.set(m.uuid,materials.length);
    materials.push({name:m.name||m.type,color:m.color?.toArray()||m.uniforms?.uColor?.value.toArray()||[.12,.15,.18],
     opacity:m.opacity??1,emission:m.emissive?.clone().multiplyScalar(m.emissiveIntensity||0).toArray()||[0,0,0],
     additive:m.blending===T.AdditiveBlending,clearcoat:m.clearcoat||0,clearcoatRoughness:m.clearcoatRoughness??.2,
     role:m===wh.mats.glowO?'orangePulse':m===wh.holo.material?'traderHolo':null});
   }});
   const p=wh.dust.geometry.attributes.position,s=wh.dust.geometry.attributes.seed,positions=[],seeds=[];
   for(let i=0;i<p.count;i++){positions.push([p.getX(i),p.getY(i),p.getZ(i)]);seeds.push(s.getX(i));}
   const samples=[];for(const time of [0,.25,1,7.5,19,31]){wh.update(0,time);samples.push({time,orange:wh.mats.glowO.emissiveIntensity,holo:wh.holo.material.opacity});}
   return {materials,dust:{positions,seeds},samples};
  });
  const manifest=JSON.parse(fs.readFileSync(path.join(root,'assets/Warehouse/Manifest.json')));
  assert.equal(result.materials.length,manifest.materials.length,'Source material traversal must match the existing bake');
  result.materials.forEach((m,i)=>{
   const d=manifest.materials[i];assert.equal(m.name,d.name,'Material identity '+i);assert.ok(Math.abs(m.opacity-d.opacity)<1e-6,'Opacity identity '+i);
   for(let k=0;k<3;k++)assert.ok(Math.abs(m.color[k]-d.color[k])<1e-6&&Math.abs(m.emission[k]-d.emission[k])<1e-6,'Color/emission identity '+i);
  });
  assert.equal(result.dust.seeds.length,900);assert.equal(result.materials.filter(m=>m.role==='traderHolo').length,1);
  const samples=result.samples;delete result.samples;
  fs.writeFileSync(path.join(root,'assets/Warehouse/Effects.json'),JSON.stringify(result));
  fs.writeFileSync(path.join(root,'tools/migration/source-warehouse-effects.json'),JSON.stringify({source:baseline.snapshot,samples},null,2));
  console.log(JSON.stringify({materials:result.materials.length,particles:result.dust.seeds.length,roles:result.materials.map((m,i)=>({i,role:m.role})).filter(m=>m.role),samples:samples.length}));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
