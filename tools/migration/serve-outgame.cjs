const fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),engine=path.join(root,'.tmp/web-engine');
const prepared=JSON.parse(fs.readFileSync(path.resolve(root,process.env.VOX_PREPARE_FILE||'.tmp/outgame-prepare.json'),'utf8').replace(/^\uFEFF/,''));
if(!prepared.ok)throw Error('Preparation failed. A cached visual fixture must be selected explicitly with VOX_PREPARE_FILE.');
const dist=path.join(prepared.source_directory,'dist');
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path,'utf8'));
const main=manifest.files.find(f=>f.fs_path==='main.lua');
const mainName=main.uuid+'-'+main.hash+main.ext;
const qa=process.argv.includes('--qa');
const probe=qa?fs.readFileSync(path.join(__dirname,'probe-outgame-web.lua'),'utf8'):'';
const port=Number(process.env.VOX_PREVIEW_PORT||4203);
const sourceCache=require('./cached-engine-sources.cjs');
const server=http.createServer((req,res)=>{
 if(req.url.startsWith('/cached-engine-source/')){
  const cached=sourceCache.read('https://tapcode-sce.spark.xd.com/'+req.url.slice('/cached-engine-source/'.length));
  if(!cached){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',cached.headers['content-type']||'application/octet-stream');res.setHeader('Cache-Control','no-store');
  res.setHeader('Cross-Origin-Resource-Policy','same-origin');res.end(cached.body);return;
 }
 const url=decodeURIComponent(req.url.split('?')[0]);const game=url.startsWith('/game-dist/');
 const base=game?dist:engine;const relative=game?url.slice('/game-dist'.length):url==='/'?'/outgame.html':url;
 const file=!game&&relative==='/outgame.html'?path.join(__dirname,'preview-outgame.html'):path.resolve(base,'.'+relative);
 if((!file.startsWith(base+path.sep)&&file!==path.join(__dirname,'preview-outgame.html'))||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
 res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[path.extname(file)]||'application/octet-stream');
 res.setHeader('Cache-Control','no-store');
 if(qa&&file.endsWith(mainName)){res.end(fs.readFileSync(file,'utf8')+'\n'+probe);return;}
 if(qa&&file===prepared.manifest_path){main.size=fs.statSync(path.join(dist,'assets',mainName)).size+Buffer.byteLength('\n'+probe);res.end(JSON.stringify(manifest));return;}
 fs.createReadStream(file).pipe(res);
});
server.listen(port,'127.0.0.1',()=>console.log(`Outgame preview: http://127.0.0.1:${port}/outgame.html?-game_url=http://127.0.0.1:${port}/game-dist/&-log=info`));
process.on('SIGINT',()=>server.close());
