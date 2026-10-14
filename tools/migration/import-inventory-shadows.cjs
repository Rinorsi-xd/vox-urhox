// Derive filter masks from frozen imported alpha, without painting new artwork.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),output=path.join(root,'assets/UI/Parts/Shadows');
const profiles={card:{size:94,blur:3},slot:{size:43,blur:3},detail:{size:200,blur:6}};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
async function main(){
 fs.mkdirSync(output,{recursive:true});
 const server=http.createServer((req,res)=>{
  const file=path.resolve(root,'assets/UI/Parts','.'+req.url);
  if(!file.startsWith(path.join(root,'assets/UI/Parts')+path.sep)||!fs.existsSync(file))return res.writeHead(404).end();
  res.setHeader('Content-Type','image/png');fs.createReadStream(file).pipe(res);
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,channel:'chrome'}),records=[];
 function write(name,bytes){
  const file=path.join(output,name);fs.writeFileSync(file,bytes);
  if(!fs.existsSync(file+'.meta'))fs.writeFileSync(file+'.meta',JSON.stringify({uuid:crypto.createHash('sha256').update('vox-source-inventory-shadow:'+name).digest('base64url').slice(0,24)},null,2)+'\n');
  return {file:'UI/Parts/Shadows/'+name,bytes:bytes.length,sha256:hash(bytes)};
 }
 try{
  const page=await browser.newPage();await page.goto('http://127.0.0.1:'+server.address().port+'/laser1.png');
  for(const name of fs.readdirSync(path.join(root,'assets/UI/Parts')).filter(n=>n.endsWith('.png'))){
   const result=await page.evaluate(async({name,profiles})=>{
    const image=new Image();image.src='/'+name;await image.decode();const masks={};
    for(const [id,{size,blur}] of Object.entries(profiles)){
     const pad=blur*4,alpha=document.createElement('canvas');alpha.width=alpha.height=size+pad*2;
     const a=alpha.getContext('2d');a.drawImage(image,pad,pad,size,size);a.globalCompositeOperation='source-in';a.fillStyle='white';a.fillRect(0,0,alpha.width,alpha.height);
     const mask=document.createElement('canvas');mask.width=mask.height=alpha.width;
     const ctx=mask.getContext('2d');ctx.filter=`blur(${blur}px)`;ctx.drawImage(alpha,0,0);masks[id]=mask.toDataURL().split(',')[1];
    }return masks;
   },{name,profiles});
   records.push({source:'UI/Parts/'+name,sourceHash:hash(fs.readFileSync(path.join(root,'assets/UI/Parts',name))),masks:Object.fromEntries(Object.entries(result).map(([id,b])=>[id,write(id+'-'+name,Buffer.from(b,'base64'))]))});
  }
  const kernels=await page.evaluate(()=>{
   const result={};
   for(const [id,blur] of Object.entries({rest:4,hover:6,press:2})){
    const c=document.createElement('canvas');c.width=c.height=176;const ctx=c.getContext('2d');ctx.filter=`blur(${blur}px)`;ctx.fillStyle='white';ctx.beginPath();ctx.moveTo(24,24);ctx.lineTo(137,24);ctx.lineTo(152,39);ctx.lineTo(152,152);ctx.lineTo(24,152);ctx.closePath();ctx.fill();result[id]=c.toDataURL().split(',')[1];
   }return result;
  });
  const tiles=Object.fromEntries(Object.entries(kernels).map(([id,b])=>[id,write('tile-'+id+'.png',Buffer.from(b,'base64'))]));
  const report={baseline:baseline.commit,algorithm:'Chromium Canvas Gaussian alpha masks; source drop-shadow standard deviation',profiles,records,tiles,totalBytes:records.reduce((n,r)=>n+Object.values(r.masks).reduce((m,v)=>m+v.bytes,0),0)};
  fs.writeFileSync(path.join(root,'docs/migration/evidence/inventory-shadow-import.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({parts:records.length,masks:records.length*3+3,bytes:report.totalBytes,baseline:baseline.commit}));
 }finally{await browser.close();await new Promise(r=>server.close(r));}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
