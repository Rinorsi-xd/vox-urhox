// Offline export host. Source files are served read-only; writes are limited to
// this project's staging directory. The browser executes the original renderer.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash, randomBytes } from 'node:crypto';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../..');
const source=path.resolve(process.argv[2] || 'D:/Rino_Project/Vox');
const port=Number(process.argv[3] || 43185);
const origin=`http://127.0.0.1:${port}`;
const staging=path.join(root,'.tmp/source-thumbnails');
const token=randomBytes(24).toString('hex');
const defs=JSON.parse(await fs.readFile(path.join(root,'assets/Parts/Catalog.json'),'utf8')).parts;
const ids=defs.map(p=>p.id);
const sourceHashes=new Map();
const sha=data=>createHash('sha256').update(data).digest('hex');
const mime={'.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.png':'image/png',
  '.glb':'model/gltf-binary','.woff2':'font/woff2','.ttf':'font/ttf','.hdr':'application/octet-stream'};
await fs.mkdir(staging,{recursive:true});

const server=http.createServer(async(req,res)=>{
  try {
    const url=new URL(req.url,origin);
    if(req.headers.host!==`127.0.0.1:${port}`) {res.writeHead(403);return res.end();}
    if(req.method==='GET' && url.pathname==='/') {
      res.setHeader('Content-Type','text/html; charset=utf-8');res.setHeader('Cache-Control','no-store');
      const html=await fs.readFile(path.join(here,'source-thumbnails.html'),'utf8');
      return res.end(html.replace('__EXPORT_TOKEN__',token));
    }
    if(req.method==='GET' && url.pathname.startsWith('/source/')) {
      const relative=decodeURIComponent(url.pathname.slice(8));
      const filename=path.resolve(source,relative);
      if(!filename.startsWith(source+path.sep) || !/^(three|shared)\//.test(relative)) throw Error('Source path rejected');
      const data=await fs.readFile(filename);sourceHashes.set(relative,sha(data));
      res.setHeader('Content-Type',mime[path.extname(filename)] || 'application/octet-stream');
      return res.end(data);
    }
    if(req.method==='POST' && url.pathname==='/export' && req.headers.origin===origin && req.headers['x-export-token']===token) {
      const chunks=[];let bytes=0;
      for await(const chunk of req) {bytes+=chunk.length;if(bytes>8*1024*1024) throw Error('Export too large');chunks.push(chunk);}
      const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if(body.size!==112 || Object.keys(body.images || {}).length!==ids.length) throw Error('Unexpected thumbnail set');
      const images=[];
      // Validate the complete batch before replacing any staged files.
      for(const id of ids) {
        const uri=body.images[id];if(typeof uri!=='string' || !/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(uri)) throw Error(`Missing PNG: ${id}`);
        const data=Buffer.from(uri.slice('data:image/png;base64,'.length),'base64');
        if(data.subarray(0,8).toString('hex')!=='89504e470d0a1a0a' || data.readUInt32BE(16)!==112 || data.readUInt32BE(20)!==112) throw Error(`Invalid PNG: ${id}`);
        images.push({id,data});
      }
      const files=[];
      for(const {id,data} of images) {
        await fs.writeFile(path.join(staging,`${id}.png`),data);
        files.push({id,bytes:data.length,sha256:sha(data)});
      }
      const manifest={source,renderer:'three/src/ui/thumbnails.js',size:112,count:files.length,
        generatedAt:new Date().toISOString(),sourceFiles:Object.fromEntries([...sourceHashes].sort()),images:files};
      await fs.writeFile(path.join(staging,'manifest.json'),JSON.stringify(manifest,null,2));
      res.setHeader('Content-Type','application/json');res.end(JSON.stringify({count:files.length,bytes:files.reduce((n,f)=>n+f.bytes,0)}));
      console.log(`Staged ${files.length} original PNGs in ${staging}`);return;
    }
    res.writeHead(404);res.end('Not found');
  } catch(error) {console.error(error.message);res.writeHead(400);res.end(error.message);}
});
server.listen(port,'127.0.0.1',()=>console.log(`Original thumbnail export: ${origin}`));
