// Read-only H5 host, explicit conversion endpoint writes only target Crater assets.
const fs=require('fs'),path=require('path'),http=require('http');
const {optimize:optimizeModel}=require('./crater-model.cjs');
const source=path.resolve('D:/Rino_Project/Vox'),root=path.resolve(__dirname,'../..'),out=path.join(root,'assets/Crater');
const raw=path.join(__dirname,'crater-source');
fs.mkdirSync(out,{recursive:true});fs.mkdirSync(raw,{recursive:true});
function mdl(g){
 const chunks=[],u=(...a)=>{let b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeUInt32LE(v,i*4));chunks.push(b)},f=(...a)=>{let b=Buffer.alloc(a.length*4);a.forEach((v,i)=>b.writeFloatLE(v,i*4));chunks.push(b)};
 const n=g.p.length/3,lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity],vb=Buffer.alloc(n*44);
 chunks.push(Buffer.from('UMDL'));u(1,n,31,0,0);
 for(let i=0;i<n;i++){
  const p=[-g.p[i*3],g.p[i*3+1],g.p[i*3+2]],normal=[-g.n[i*3],g.n[i*3+1],g.n[i*3+2]];
  p.forEach((v,k)=>{lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v)});
  [...p,...normal].forEach((v,k)=>vb.writeFloatLE(v,i*44+k*4));
  for(let k=0;k<4;k++)vb[i*44+24+k]=Math.round(Math.max(0,Math.min(1,g.c[i*4+k]))*255);
  [g.uv[i*2],g.uv[i*2+1],g.uv2[i*2],g.uv2[i*2+1]].forEach((v,k)=>vb.writeFloatLE(v,i*44+28+k*4));
 }
 chunks.push(vb);u(1,g.idx.length,4);const ib=Buffer.alloc(g.idx.length*4);
 for(let i=0;i<g.idx.length;i+=3)[g.idx[i],g.idx[i+2],g.idx[i+1]].forEach((v,k)=>ib.writeUInt32LE(v,(i+k)*4));
 chunks.push(ib);u(1,0,1);f(0);u(0,0,0,0,g.idx.length);u(0,0);f(...lo,...hi);f(...lo.map((v,i)=>(v+hi[i])/2));return optimizeModel(Buffer.concat(chunks));
}
const html=`<!doctype html><meta charset="utf-8"><title>坠舰陨坑原资源转换</title><style>body{background:#16191e;color:white;font:16px sans-serif}canvas{max-width:90vw}</style><script type="importmap">{"imports":{"three":"/three/vendor/three/build/three.module.js","three/addons/":"/three/vendor/three/addons/","@shared/":"/shared/"}}</script><button id="export">转换原地图</button><pre id="status">等待转换</pre><script type="module" src="/crater-export-browser.js"></script>`;
http.createServer(async(req,res)=>{try{
 const url=new URL(req.url,'http://localhost');
 if(req.method==='POST'&&url.pathname.startsWith('/evidence/')){
  const name=url.pathname.slice(10);if(!/^crater-h5-post-[\w-]+\.(png|json)$/.test(name))throw Error('Invalid evidence output');
  const parts=[];for await(const part of req)parts.push(part);
  fs.writeFileSync(path.join(root,'docs/migration/evidence',name),Buffer.concat(parts));res.end('ok');return;
 }
 if(req.method==='POST'&&url.pathname.startsWith('/export/')){
  const name=url.pathname.slice(8);if(!/^[\w.-]+$/.test(name))throw Error('Invalid output');
  const parts=[];for await(const part of req)parts.push(part);const body=Buffer.concat(parts);
  fs.writeFileSync(path.join(name.endsWith('.json')?raw:out,name),name.endsWith('.mdl')?mdl(JSON.parse(body)):body);res.end('ok');return;
 }
 if(url.pathname==='/three/crater-export.html'){res.setHeader('Content-Type','text/html');res.end(html);return}
 if(url.pathname==='/three/crater-post-probe.html'){
  res.setHeader('Content-Type','text/html');res.end(html.replace('<button id="export">转换原地图</button>','').replace('/crater-export-browser.js','/crater-post-browser.js'));return;
 }
 if(url.pathname==='/crater-post-browser.js'){res.setHeader('Content-Type','text/javascript');res.end(fs.readFileSync(path.join(__dirname,'crater-post-browser.js')));return;}
 const file=url.pathname==='/crater-export-browser.js'?path.join(__dirname,'crater-export-browser.js'):path.resolve(source,'.'+decodeURIComponent(url.pathname));
 if(!file.startsWith(source+path.sep)&&file!==path.join(__dirname,'crater-export-browser.js'))throw Error('Invalid path');
 res.setHeader('Content-Type',({'.js':'text/javascript','.html':'text/html','.json':'application/json','.wasm':'application/wasm','.png':'image/png'})[path.extname(file)]||'application/octet-stream');
 const data=await fs.promises.readFile(file);res.end(data);
 }catch(e){res.writeHead(500);res.end(String(e))}}).listen(43187,'127.0.0.1',()=>console.log('Crater converter http://127.0.0.1:43187/three/crater-export.html'));
