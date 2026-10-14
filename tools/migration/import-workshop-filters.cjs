// Bake the frozen CSS filters with Chromium; tint cannot reproduce saturation.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=path.join(baseline.snapshot,'shared/assets/ui/prefabs');
const css=fs.readFileSync(path.join(baseline.snapshot,'shared/css/workshop.css'),'utf8');
const filters={card:'.wsb-card img',hover:'.wsb-card:hover img',dot:'.wsh-dots img'};
const outputArg=process.argv.find(arg=>arg.startsWith('--output='));
const folder=outputArg?path.resolve(outputArg.slice('--output='.length)):path.join(root,'assets/UI/Prefabs/Filtered');
if(outputArg&&fs.existsSync(folder)&&fs.readdirSync(folder).length)throw Error('Isolated output must be empty');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const inputs=[{file:'shared/css/workshop.css',sha256:hash(Buffer.from(css))}],outputs=[];
for(const [name,selector] of Object.entries(filters)){
 const rule=css.split('\n').find(line=>line.includes(selector+' {')&&line.includes('filter:'));
 const value=rule?.match(/(?:^|[;{])\s*filter:\s*([^;]+)/)?.[1];
 if(!value)throw Error('Frozen filter missing: '+selector);
 filters[name]=value.trim();
}
(async()=>{
 const server=http.createServer((req,res)=>{
  if(req.url==='/')return res.writeHead(200,{'Content-Type':'text/html'}).end('<!doctype html><title>Frozen CSS filter export</title>');
  const name=path.basename(req.url);
  if(!name.endsWith('.jpg'))return res.writeHead(404).end();
  res.setHeader('Content-Type','image/jpeg');fs.createReadStream(path.join(source,name)).pipe(res);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  const page=await browser.newPage();
  await page.goto('http://127.0.0.1:'+server.address().port+'/');
  fs.mkdirSync(folder,{recursive:true});
  for(const file of fs.readdirSync(source).filter(file=>file.endsWith('.jpg'))){
   inputs.push({file:'shared/assets/ui/prefabs/'+file,sha256:hash(fs.readFileSync(path.join(source,file)))});
   for(const [name,filter] of Object.entries(filters)){
    const data=await page.evaluate(async({url,filter,thumbnail})=>{
     const image=new Image();image.src=url;await image.decode();
     const canvas=document.createElement('canvas');canvas.width=thumbnail?264:image.width;
     canvas.height=Math.round(image.height*canvas.width/image.width);
     const context=canvas.getContext('2d');context.filter=filter;
     context.drawImage(image,0,0,canvas.width,canvas.height);
     return canvas.toDataURL('image/jpeg',.98).split(',')[1];
    },{url:'http://127.0.0.1:'+server.address().port+'/'+file,filter,thumbnail:name==='dot'});
    const bytes=Buffer.from(data,'base64');fs.writeFileSync(path.join(folder,name+'-'+file),bytes);
    outputs.push({file:'UI/Prefabs/Filtered/'+name+'-'+file,sha256:hash(bytes),bytes:bytes.length});
   }
  }
  const provenance={sourceCommit:baseline.commit,converter:'tools/migration/import-workshop-filters.cjs',converterSha256:hash(fs.readFileSync(__filename)),browser:browser.version(),filters,inputs,outputs};
  if(outputArg)fs.writeFileSync(path.join(folder,'provenance.json'),JSON.stringify(provenance,null,2));
  console.log(JSON.stringify({filters,images:outputs.length,output:folder}));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
