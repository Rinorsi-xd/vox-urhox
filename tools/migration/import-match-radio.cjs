// Execute the hash-checked frozen Radio graph; only isolate output stems.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const sourcePath='shared/audio/radio.js',sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=fs.readFileSync(path.join(baseline.snapshot,sourcePath));assert.equal(sha(source),baseline.files[sourcePath].sha256);
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/Combat/Radio.json'))),rate=48000;
function write(file,b){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,b);if(!fs.existsSync(file+'.meta'))fs.writeFileSync(file+'.meta',JSON.stringify({uuid:crypto.randomUUID()},null,2)+'\n');}
function wav(samples){const b=Buffer.alloc(44+samples.length*2);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(samples.length*2,40);for(let i=0;i<samples.length;i++){assert.ok(Math.abs(samples[i])<1,'unclipped source stem');b.writeInt16LE(Math.round(samples[i]*32767),44+i*2);}return b;}
(async()=>{
 const server=http.createServer((req,res)=>{
  const url=new URL(req.url,'http://localhost');
  if(url.pathname==='/')return res.end('<!doctype html><title>Frozen Match Radio offline capture</title>');
  if(url.pathname==='/shared/audio/levels.js'){res.setHeader('Content-Type','text/javascript');return res.end('export const DEFAULT_LEVELS={voice:.6}; export const levels={speaking:0,on:(key,fn)=>{fn(.6);return()=>{};}};');}
  const file=path.resolve(baseline.snapshot,'.'+decodeURIComponent(url.pathname));
  if(!file.startsWith(baseline.snapshot+path.sep)||!fs.existsSync(file))return res.writeHead(404).end();
  res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'application/octet-stream');res.end(fs.readFileSync(file));
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--disable-gpu']});const page=await browser.newPage();await page.goto('http://127.0.0.1:'+server.address().port+'/');
  const lines={},evidence=[];let common;
  for(const id of Object.keys(data.lines)){
   const rendered=await page.evaluate(async({id,rate})=>{
    const {Radio}=await import('/shared/audio/radio.js'),seed=0x56a17;let random=seed;
    const originalRandom=Math.random;Math.random=()=>{random=(Math.imul(random,1664525)+1013904223)>>>0;return random/4294967296;};
    const originalTimer=window.setTimeout;window.setTimeout=()=>0;
    async function render(lane){
     random=seed;const ctx=new OfflineAudioContext(1,Math.ceil(rate*10),rate);window.AudioContext=function(){return ctx;};
     const radio=new Radio(['bc/'+id+'.wav']);await radio.ready;radio.level.gain.value=1;
     const duration=radio.duration(id);if(!(duration>0&&duration<9))throw Error('Missing/oversized source voice '+id);
     const fx=radio.fxIn,mute=ctx.createGain(),src=radio._src,stat=radio._static,beep=radio._beep,events=[];mute.gain.value=0;mute.connect(fx);
     // Keep decoded hiss connected, including its channel topology and onended.
     radio._src=function(buffer,dest,at,vol,options){const kind=dest===this.voiceIn?'voice':'hiss';events.push({kind,at,stop:options?.stop??null});return src.call(this,buffer,dest,at,lane==='all'||lane===kind?vol:0,options);};
     radio._static=function(at,...args){const kind=at<.26?'lead':'tail';events.push({kind,type:'static',at});this.fxIn=lane==='all'||lane===kind?fx:mute;stat.call(this,at,...args);this.fxIn=fx;};
     radio._beep=function(at,...args){const kind=at<.26?'lead':'tail';events.push({kind,type:'beep',at});this.fxIn=lane==='all'||lane===kind?fx:mute;beep.call(this,at,...args);this.fxIn=fx;};
     const total=radio.say(id),randomEnd=random,audio=await ctx.startRendering();return {samples:audio.getChannelData(0).slice(0,Math.ceil((duration+.75)*rate)),duration,total,events,randomEnd};
    }
    try{
     const all=await render('all'),parts={};for(const lane of ['voice','hiss','lead'])parts[lane]=await render(lane);
     // Source onended disconnects can change the shared FX channel topology.
     // Keep that return transient from the actual full mix, rather than a new graph.
     const returned=new Float32Array(all.samples.length),returnAt=Math.round((.26+all.duration)*rate);
     for(let i=returnAt;i<returned.length;i++)returned[i]=all.samples[i]-parts.voice.samples[i]-parts.hiss.samples[i]-parts.lead.samples[i];
     parts.tail={samples:returned};
     let error=0,power=0;for(let i=0;i<all.samples.length;i++){let sum=0;for(const p of Object.values(parts))sum+=p.samples[i];error=Math.max(error,Math.abs(sum-all.samples[i]));power+=all.samples[i]**2;}
     if(error>2/32767){let index=0;for(let i=0;i<all.samples.length;i++){let sum=0;for(const p of Object.values(parts))sum+=p.samples[i];if(Math.abs(sum-all.samples[i])===error)index=i;}throw Error('Source stem reconstruction mismatch '+JSON.stringify({error,time:index/rate}));}
     const offsets={voice:.26,hiss:.06,lead:.02,tail:.26+all.duration},ends={voice:.26+all.duration+.16,hiss:.34+all.duration+.08,lead:.22,tail:.26+all.duration+.38};
     const stems={};for(const [lane,p]of Object.entries(parts)){const start=Math.round(offsets[lane]*rate),end=Math.ceil(ends[lane]*rate);stems[lane]=Array.from(p.samples.slice(start,end));}
     let exportedError=0;for(let i=0;i<all.samples.length;i++){let mix=0;for(const [lane,s]of Object.entries(stems)){const index=i-Math.round(offsets[lane]*rate);if(index>=0&&index<s.length)mix+=Math.round(s[index]*32767)/32767;}exportedError=Math.max(exportedError,Math.abs(mix-all.samples[i]));}
     if(exportedError>4/32767)throw Error('Exported PCM reconstruction mismatch '+exportedError);
     return {duration:all.duration,total:all.total,offsets,stems,error,exportedError,rms:Math.sqrt(power/all.samples.length),events:all.events};
    }finally{Math.random=originalRandom;window.setTimeout=originalTimer;}
   },{id,rate});
   const stems={};for(const [lane,samples]of Object.entries(rendered.stems)){
    const name=lane==='lead'?lane:id+'-'+lane;
    const relative='Sounds/BattleRadioDSP/'+name+'.wav',b=wav(samples);
    if(lane==='lead'){
     if(common){assert.equal(sha(b),common[lane].sha256,'common source '+lane);}else write(path.join(root,'assets',relative),b);
    }else write(path.join(root,'assets',relative),b);
    stems[lane]={path:relative,sha256:sha(b),bytes:b.length,seconds:samples.length/rate,at:rendered.offsets[lane]};
   }
   if(!common)common={lead:stems.lead};
   lines[id]={duration:rendered.duration,total:rendered.total,speaking:rendered.duration+.5,stems};
   evidence.push({id,reconstructionMaxError:rendered.error,exportedPcmMaxError:rendered.exportedError,sourceRms:rendered.rms,events:rendered.events});
   process.stdout.write(id+' ');
  }
  const inputs={};for(const id of Object.keys(data.lines)){const p='shared/assets/match/vo/bc/'+id+'.wav';inputs[p]=sha(fs.readFileSync(path.join(baseline.snapshot,p)));}
  const hiss='shared/assets/match/vo/sfx_radio_hiss.mp3';inputs[hiss]=sha(fs.readFileSync(path.join(baseline.snapshot,hiss)));
  const report={baseline:baseline.commit,source:sourcePath,sourceSha256:sha(source),sampleRate:rate,format:'mono PCM16',bakedMaster:1,runtimeGain:.7*.4,seed:0x56a17,lines,inputs,
   boundary:'Actual frozen Radio constructor/say/DSP executed. Seeded noise and initial LFO phase are deterministic variants. User settings and route gain are not baked. Runtime frame scheduling is not sample accurate.'};
  write(path.join(root,'assets/Combat/MatchRadioDSP.json'),JSON.stringify(report,null,2)+'\n');
  fs.writeFileSync(path.join(root,'docs/migration/evidence/match-radio-source.json'),JSON.stringify({result:'PASS',...report,oracle:evidence},null,2)+'\n');
  console.log('\n'+JSON.stringify({lines:Object.keys(lines).length,maxReconstructionError:Math.max(...evidence.map(x=>x.reconstructionMaxError))}));
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
