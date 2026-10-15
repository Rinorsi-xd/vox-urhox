// Render the frozen game's WebAudio graph offline; no re-authored sound design.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const relative='shared/ui/salvageRunHud.js',source=fs.readFileSync(path.join(baseline.snapshot,relative));
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
assert.equal(sha(source),baseline.files[relative].sha256);
function write(file,data){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,data);if(!fs.existsSync(file+'.meta'))fs.writeFileSync(file+'.meta',JSON.stringify({uuid:crypto.randomUUID()},null,2)+'\n');}
function wav(samples,rate){
 const b=Buffer.alloc(44+samples.length*2);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(samples.length*2,40);
 for(let i=0;i<samples.length;i++)b.writeInt16LE(Math.round(Math.max(-1,Math.min(1,samples[i]))*32767),44+i*2);return b;
}
(async()=>{
 const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://localhost');
  if(url.pathname==='/'){res.setHeader('Content-Type','text/html');return res.end('<!doctype html><title>Frozen salvage audio capture</title>');}
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(url.pathname));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file))return res.writeHead(404).end();
  res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'application/octet-stream');
  if(url.pathname==='/'+relative)return res.end(source.toString()+'\nexport function capture(context, rarity) { actx=context; sfx.setVolume(1); if(rarity===null)heartbeat(); else tone(rarity); }\n');
  res.end(fs.readFileSync(file));
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,channel:'chrome'});
 try{
  const page=await browser.newPage();await page.goto('http://127.0.0.1:'+server.address().port+'/');
  const cues={},rate=48000;
  for(const rarity of [0,1,2,3,4,5,null]){
   const samples=await page.evaluate(async({rarity,rate})=>{
    const ctx=new OfflineAudioContext(1,Math.round(rate*(rarity===null?.64:rarity===5?1.6:1)),rate);
    ctx.resume=()=>Promise.resolve();
    const module=await import('/shared/ui/salvageRunHud.js');module.capture(ctx,rarity);
    const result=await ctx.startRendering();return Array.from(result.getChannelData(0));
   },{rarity,rate});
   const id=rarity===null?'suspense':'reveal'+rarity,relative='Sounds/Salvage/'+id+'.wav',data=wav(samples,rate);
   const peak=Math.max(...samples.map(Math.abs));assert.ok(peak>.01&&peak<.8,'valid source waveform '+id);
   write(path.join(root,'assets',relative),data);cues[id]={path:relative,bytes:data.length,sha256:sha(data),seconds:samples.length/rate,peak};
  }
  const report={baseline:baseline.commit,source:relative,sourceSha256:sha(source),sampleRate:rate,format:'mono PCM16',sourceVolume:1,cues};
  write(path.join(root,'assets/Salvage/RevealSounds.json'),JSON.stringify(report,null,2)+'\n');
  fs.writeFileSync(path.join(root,'docs/migration/evidence/salvage-audio-source.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({baseline:baseline.commit,cues:Object.keys(cues).length,bytes:Object.values(cues).reduce((s,c)=>s+c.bytes,0)}));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
