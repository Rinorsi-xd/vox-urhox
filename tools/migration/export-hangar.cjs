// Reproducible, read-only H5 -> native UrhoX scene export. No browser runtime ships.
const fs = require('fs'), path = require('path'), http = require('http');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const source = path.resolve(process.argv[2] || 'D:/Rino_Project/Vox');
const target = path.resolve(__dirname, '../..');
const panelsOnly=process.argv.includes('--panels-only');
// Staging protects the authored scene and material edits from reimport.
const staging = path.join(target, '.tmp/hangar-import');
const out = path.join(staging, 'Hangar');
fs.mkdirSync(out, {recursive:true});
function lua(v) {
  if(v == null) return 'nil';
  if(typeof v === 'string') return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g,'\\u{$1}');
  if(typeof v !== 'object') return String(v);
  if(Array.isArray(v)) return '{'+v.map(lua).join(',')+'}';
  return '{'+Object.entries(v).filter(([k,v])=>v != null).map(([k,v])=>'['+lua(k)+']='+lua(v)).join(',')+'}';
}
let meshCount=0, vertices=0, triangles=0;
function mesh(g) {
  // UMDL is the engine's documented legacy Model format; positions/normals mirrored in X.
  const chunks=[]; const u=(...a)=>{const b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeUInt32LE(v,i*4));chunks.push(b);};
  const f=(...a)=>{const b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeFloatLE(v,i*4));chunks.push(b);};
  const n=g.p.length/3, indices=g.idx||Array.from({length:n},(_,i)=>i);
  const lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
  chunks.push(Buffer.from('UMDL'));u(1,n,11,0,0);
  const data=Buffer.alloc(n*32);
  for(let i=0;i<n;i++) {
    const p=[-g.p[i*3],g.p[i*3+1],g.p[i*3+2]];
    p.forEach((v,k)=>{lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v);});
    [...p,-g.n[i*3],g.n[i*3+1],g.n[i*3+2],g.uv?.[i*2]||0,1-(g.uv?.[i*2+1]||0)].forEach((v,k)=>data.writeFloatLE(v,i*32+k*4));
  }
  chunks.push(data);u(1,indices.length,4);
  const ib=Buffer.alloc(indices.length*4);
  for(let i=0;i<indices.length;i+=3) [indices[i],indices[i+2],indices[i+1]].forEach((v,k)=>ib.writeUInt32LE(v,(i+k)*4));
  chunks.push(ib);u(1,0,1);f(0);u(0,0,0,0,indices.length);u(0,0);f(...lo,...hi);f(...lo.map((v,i)=>(v+hi[i])/2));
  const name='mesh-'+String(++meshCount).padStart(3,'0')+'.mdl';
  fs.writeFileSync(path.join(out,name),Buffer.concat(chunks));vertices+=n;triangles+=indices.length/3;
  return 'Hangar/'+name;
}
function replaceGeos(v) {
  if(!v||typeof v!=='object') return v;
  if(v.p && v.n) return mesh(v);
  if(Array.isArray(v)) return v.map(replaceGeos);
  return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,replaceGeos(x)]));
}
(async()=>{
  const server=http.createServer((req,res)=>{
    const file=path.resolve(source,'.'+decodeURIComponent(new URL(req.url,'http://local').pathname));
    if(!file.startsWith(source+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory()) {res.writeHead(404).end();return;}
    const mime={'.js':'text/javascript','.css':'text/css','.html':'text/html','.ttf':'font/ttf','.woff2':'font/woff2'};
    res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
  });
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const browser=await chromium.launch({headless:true,channel:'msedge'});
  try {
    const page=await browser.newPage({viewport:{width:1600,height:900}});
    page.on('pageerror',e=>console.error('PAGE',e.message));
    const base='http://127.0.0.1:'+server.address().port;
    await page.goto(base+'/three/index.html');
    await page.waitForFunction(()=>window.__vox,{timeout:180000});
    const native=JSON.parse(fs.readFileSync(path.join(__dirname,'native-panels.json'),'utf8'));
    native.panelsOnly=panelsOnly;
    const data=await page.evaluate(async native=>{
      const H=await import('/shared/scene/hangarLayout.js');
      const {Geo,cylinderGeo}=await import('/shared/parts/geo.js');
      const garage=window.__vox.editor.garage;
      const L=garage.layout;
      const plain=g=>({p:Array.from(g.position),n:Array.from(g.normal),uv:g.uv?Array.from(g.uv):null,idx:g.idx?Array.from(g.idx):null});
      const clean=v=>{
        if(v instanceof Geo) return plain(v);
        if(v instanceof HTMLCanvasElement) return undefined;
        if(ArrayBuffer.isView(v)) return Array.from(v);
        if(Array.isArray(v)) return v.map(clean);
        if(v&&typeof v==='object') return Object.fromEntries(Object.entries(v).filter(([k,v])=>typeof v!=='function').map(([k,v])=>[k,clean(v)]));
        return v;
      };
      const textures={};
      for(const [k,v] of Object.entries(L.tex)) if(v.canvas instanceof HTMLCanvasElement) textures[k]=v.canvas.toDataURL('image/png');
      // Use the existing native race-car blueprint for the two in-world information panels.
      const {PARTS}=await import('/shared/parts/defs.js');
      const hp=await import('/shared/scene/holoPanels.js');
      const ht=await import('/shared/scene/hangarTextures.js');
      for(const def of native.defs)PARTS[def.id]=def;
      const bp={name:native.name,parts:new Map(native.parts.map(p=>[p.id,p]))};
      const panels={};
      // Only the authored T3 editor fallback is baked; runtime canvases are live.
      for(const tier of native.tiers.filter(tier=>tier.id===3)) {
        const diag=native.diagnostics[tier.id-1];
        diag.list=Array.isArray(diag.list)?diag.list:[];
        diag.stats.parts=diag.stats.parts??diag.stats.count;
        diag.conn.floating={size:diag.conn.floatingCount};
        const info={name:bp.name,tier,diag,bp,slot:null,no:'--'};
        panels[tier.id]={};
        for(const [key,draw] of [['stats',hp.drawStatsPanel],['blueprint',hp.drawBlueprintPanel]]) {
          const c=hp.makeHoloCanvas();draw(c,info);panels[tier.id][key]=c.toDataURL('image/png');
        }
        for(const [key,make,draw] of [['mark',ht.wallMark,ht.drawWallMark],['bay',ht.bayDecal,ht.drawBayDecal]]) {
          const c=make().canvas;draw(c,info);panels[tier.id][key]=c.toDataURL('image/png');
        }
      }
      if(native.panelsOnly)return {panels};
      const niches=garage.niches.map(root=>{
        const items=[];root.updateMatrixWorld(true);
        const inv=root.matrixWorld.clone().invert();
        root.traverse(o=>{if(!o.isMesh)return;
          const g=o.geometry.clone();g.applyMatrix4(inv.clone().multiply(o.matrixWorld));
          const ms=Array.isArray(o.material)?o.material:[o.material];
          const groups=g.groups.length?g.groups:[{start:0,count:g.index?g.index.count:g.attributes.position.count,materialIndex:0}];
          for(const gr of groups){const m=ms[gr.materialIndex]; const idx=g.index?Array.from(g.index.array).slice(gr.start,gr.start+gr.count):Array.from({length:gr.count},(_,i)=>i+gr.start);
            items.push({geo:{p:Array.from(g.attributes.position.array),n:Array.from(g.attributes.normal.array),uv:g.attributes.uv?Array.from(g.attributes.uv.array):null,idx},color:m.color?.toArray()||[0.4,0.4,0.4],emission:m.emissive?.toArray()||[0,0,0],intensity:m.emissiveIntensity||0,rough:m.roughness??0.5,metal:m.metalness??0,coat:m.clearcoat||0,opacity:m.opacity});}
        });return {pos:root.position.toArray(),scale:root.scale.toArray(),items};
      });
      return {layout:clean(L),mats:H.HANGAR_MATS,room:H.HANGAR,arm:H.ARM,textures,panels,niches,sky:plain(cylinderGeo(160,160,220,64,1,true,Math.PI-1.45,2.9))};
    },native);
    if(panelsOnly){
      for(const [tier,ps] of Object.entries(data.panels))for(const [k,v]of Object.entries(ps))fs.writeFileSync(path.join(target,'assets/Hangar',k+'-t'+tier+'.png'),Buffer.from(v.split(',')[1],'base64'));
      console.log('Updated four T3 editor fallback canvases from native blueprint');return;
    }
    for(const [k,v] of Object.entries(data.textures))fs.writeFileSync(path.join(out,k+'.png'),Buffer.from(v.split(',')[1],'base64'));
    for(const [tier,ps] of Object.entries(data.panels))for(const [k,v]of Object.entries(ps))fs.writeFileSync(path.join(out,k+'-t'+tier+'.png'),Buffer.from(v.split(',')[1],'base64'));
    delete data.textures;delete data.panels;delete data.layout.tex;
    const exported=replaceGeos(data);
    fs.writeFileSync(path.join(staging,'HangarData.lua'),'-- Import staging; reconcile with the authored scene.\nreturn '+lua(exported)+'\n');
    fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({source,exportedAt:new Date().toISOString(),meshCount,vertices,triangles,planes:data.layout.planes.length,arms:data.layout.arms.length,niches:data.niches.length},null,2));
    const evidence=path.join(target,'docs/migration/evidence');
    fs.mkdirSync(evidence,{recursive:true});
    await page.screenshot({path:path.join(evidence,'h5-start.png')});
    console.log(JSON.stringify({meshCount,vertices,triangles}));
    // Keep baking separate, so export failures never silently reuse the old garage IBL.
    const bake=fs.readFileSync(path.join(__dirname,'environment-capture.html'),'utf8');
    const code=bake.match(/<script type="module">([\s\S]*?)<\/script>/)[1]
      .replace(/import .*?;\s*/g,'')
      .replace(/const scene = new THREE.Scene\(\);[\s\S]*?garage.dust.visible = false;/,'const scene = window.__vox.scene; const garage = window.__vox.editor.garage; const hidden=[]; scene.traverse(o=>{if(o.visible && (o===window.__vox.editor.view.root || o.isSprite || o.isPoints || o.material?.blending===THREE.AdditiveBlending)){hidden.push(o);o.visible=false;}}); scene.environment=null;')
      .replace('0.1, 100, cubeRT','0.1, 320, cubeRT')
      .replace('renderer.shadowMap.type = THREE.VSMShadowMap','renderer.shadowMap.type = THREE.PCFShadowMap')
      .replace(/const res = await fetch\([\s\S]*?log\( 'DONE' \);/,'window.__hangarHDR=Array.from(out); window.__hangarBakeDone=true; renderer.dispose(); for(const o of hidden)o.visible=true;')
      .replace(/^const log = .*$/m,'const log = console.log;');
    await page.evaluate(async code=>{const THREE=await import('/three/vendor/three/build/three.module.js');await (new Function('THREE','return (async()=>{'+code+'})()'))(THREE);},code);
    const hdr=await page.evaluate(()=>window.__hangarHDR);
    if(!hdr)throw new Error('Environment capture failed');
    fs.writeFileSync(path.join(out,'HangarEnv.hdr'),Buffer.from(hdr));
  } finally {await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exit(1);});
