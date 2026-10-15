// Local, read-only source host; only the three named comparison PNGs are writable.
import http from 'node:http';import fs from 'node:fs/promises';import path from 'node:path';
import {fileURLToPath} from 'node:url';import {randomBytes} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../..'),source='D:/Rino_Project/Vox';
const port=43189,origin=`http://127.0.0.1:${port}`,token=randomBytes(24).toString('hex');
http.createServer(async(req,res)=>{try{
 if(req.headers.host!==`127.0.0.1:${port}`)throw Error('Invalid host');
 const url=new URL(req.url,origin);res.setHeader('Cache-Control','no-store');
 if(req.method==='GET'&&url.pathname==='/'){
  res.setHeader('Content-Type','text/html; charset=utf-8');return res.end((await fs.readFile(path.join(here,'wheel-size-reference.html'),'utf8')).replace('__TOKEN__',token));
 }
 if(req.method==='GET'&&url.pathname.startsWith('/source/')){
  const rel=decodeURIComponent(url.pathname.slice(8)),file=path.resolve(source,rel);
  if(!file.startsWith(path.resolve(source)+path.sep)||!/^(three|shared)\//.test(rel))throw Error('Invalid path');
  res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'application/octet-stream');return res.end(await fs.readFile(file));
 }
 if(req.method==='POST'&&url.pathname==='/capture'&&req.headers.origin===origin&&req.headers['x-probe-token']===token){
  const chunks=[];let size=0;for await(const c of req){size+=c.length;if(size>20*1024*1024)throw Error('Too large');chunks.push(c);}
  const images=JSON.parse(Buffer.concat(chunks));
  for(const name of ['front','top','angle']){
   if(!/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(images[name]))throw Error('Invalid PNG');
   const bytes=Buffer.from(images[name].split(',')[1],'base64');
   if(bytes.readUInt32BE(16)!==1280||bytes.readUInt32BE(20)!==800)throw Error('Invalid size');
   await fs.writeFile(path.join(root,'docs/migration/evidence/wheel-size-h5-'+name+'.png'),bytes);
  }
  return res.end('ok');
 }
 res.writeHead(404);res.end();
}catch(e){res.writeHead(400);res.end(String(e));}}).listen(port,'127.0.0.1',()=>console.log(origin));
