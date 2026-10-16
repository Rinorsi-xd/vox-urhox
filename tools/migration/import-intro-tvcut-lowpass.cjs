// Execute only the frozen _play filter branch at unity gain; runtime owns all envelopes.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),baseline=require('../../docs/migration/outgame-baseline.json');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const inputs=['three/src/intro/introAudio.js','three/src/intro/introStory.js','shared/assets/intro/audio/sfx_tv_cut.mp3'];
const provenance=Object.fromEntries(inputs.map(name=>{const bytes=fs.readFileSync(path.join(baseline.snapshot,name)),hash=sha(bytes);assert.equal(hash,baseline.files[name].sha256,'Frozen actual input '+name);return [name,hash];}));
const audioSource=fs.readFileSync(path.join(baseline.snapshot,inputs[0]),'utf8'),story=fs.readFileSync(path.join(baseline.snapshot,inputs[1]),'utf8');
assert.match(story,/sfx\( 'tv_cut', \{ vol: 0\.5, lowpass: 1800 \} \)/);
assert.match(story,/setTimeout\( \(\) => cut\?\.stop\( 0\.15 \), 450 \)/);
assert.match(audioSource,/f\.type = 'lowpass'; f\.frequency\.value = lowpass; f\.Q\.value = 0\.5/);
const rate=48000,relative='Intro/Audio/sfx_tv_cut_lowpass1800.wav',target=path.join(root,'assets',relative);
function pcm(channels){
 const count=channels.length,length=channels[0].length,b=Buffer.alloc(44+length*count*2);
 b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(count,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*count*2,28);b.writeUInt16LE(count*2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(length*count*2,40);
 let peak=0,quantizationError=0;
 for(let i=0;i<length;i++)for(let c=0;c<count;c++){const value=channels[c][i];assert.ok(Number.isFinite(value)&&Math.abs(value)<1,'No normalization/clipping is needed');const q=Math.round(value*32767);b.writeInt16LE(q,44+(i*count+c)*2);peak=Math.max(peak,Math.abs(value));quantizationError=Math.max(quantizationError,Math.abs(q/32767-value));}
 return {bytes:b,peak,quantizationError,frames:length,channels:count};
}
async function run(){
 if(process.argv.includes('--check-source')){console.log(JSON.stringify({result:'PASS',baseline:baseline.commit,provenance,filter:{type:'lowpass',frequency:1800,Q:.5},runtime:{vol:.5,stopAfter:.45,stopFade:.15},browserStarted:false}));return;}
 const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
 const server=http.createServer((req,res)=>{
  if(req.url==='/')return res.end('<!doctype html><title>Frozen intro TV cut filter capture</title>');
  if(req.url==='/introAudio.js'){
   res.setHeader('Content-Type','text/javascript');
   return res.end(audioSource.replaceAll("'@shared/ui/uiSound.js'","'/stubs.js'").replaceAll("'@shared/audio/levels.js'","'/stubs.js'").replaceAll("'@shared/audio/musicPlayer.js'","'/stubs.js'"));
  }
  if(req.url==='/stubs.js'){res.setHeader('Content-Type','text/javascript');return res.end('export const sfx={},levels={},DEFAULT_LEVELS={}; export const musicGain=x=>x;');}
  if(req.url==='/original.mp3'){res.setHeader('Content-Type','audio/mpeg');return res.end(fs.readFileSync(path.join(baseline.snapshot,inputs[2])));}
  res.writeHead(404).end();
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));let browser;
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',args:['--disable-gpu']});const page=await browser.newPage();await page.goto('http://127.0.0.1:'+server.address().port+'/');
  const rendered=await page.evaluate(async(rate)=>{
   const {IntroAudio}=await import('/introAudio.js'),decode=new OfflineAudioContext(2,1,rate),input=await decode.decodeAudioData(await fetch('/original.mp3').then(r=>r.arrayBuffer()));
   async function render(actual,lowpass=1800){
    const ctx=new OfflineAudioContext(input.numberOfChannels,input.length,rate),trace={gains:[],filters:[],compressors:0};
    const createGain=ctx.createGain.bind(ctx),createFilter=ctx.createBiquadFilter.bind(ctx),createCompressor=ctx.createDynamicsCompressor.bind(ctx);
    ctx.createGain=()=>{const g=createGain();trace.gains.push(g);return g;};ctx.createBiquadFilter=()=>{const f=createFilter();trace.filters.push(f);return f;};ctx.createDynamicsCompressor=()=>{trace.compressors++;return createCompressor();};
    if(actual){const audio=Object.create(IntroAudio.prototype);audio.ctx=ctx;audio.buf=new Map([['sfx_tv_cut',input]]);audio._play('sfx_tv_cut',ctx.destination,{vol:1,lowpass});}
    else{const src=ctx.createBufferSource(),f=ctx.createBiquadFilter();src.buffer=input;f.type='lowpass';f.frequency.value=1800;f.Q.value=.5;src.connect(f).connect(ctx.destination);src.start();}
    const out=await ctx.startRendering(),channels=Array.from({length:out.numberOfChannels},(_,i)=>out.getChannelData(i));
    const filter=trace.filters[0],frequencies=new Float32Array([100,500,1800,4000,8000,12000]),magnitude=new Float32Array(frequencies.length),phase=new Float32Array(frequencies.length);
    if(filter)filter.getFrequencyResponse(frequencies,magnitude,phase);
    return {channels,trace:{gains:trace.gains.map(g=>g.gain.value),filters:trace.filters.map(f=>({type:f.type,frequency:f.frequency.value,Q:f.Q.value})),compressors:trace.compressors},response:Array.from(frequencies,(hz,i)=>({hz,magnitude:magnitude[i],db:20*Math.log10(magnitude[i])}))};
   }
   const actual=await render(true),reference=await render(false),raw=await render(true,0);let referenceError=0,rawError=0,diffPower=0,power=0;
   for(let c=0;c<input.numberOfChannels;c++)for(let i=0;i<input.length;i++){const a=actual.channels[c][i],b=reference.channels[c][i],v=raw.channels[c][i];referenceError=Math.max(referenceError,Math.abs(a-b));rawError=Math.max(rawError,Math.abs(a-v));diffPower+=(a-v)**2;power+=a*a;}
   return {channels:actual.channels.map(a=>Array.from(a)),sampleRate:input.sampleRate,inputFrames:input.length,inputChannels:input.numberOfChannels,inputDuration:input.duration,trace:actual.trace,response:actual.response,referenceError,rawError,differenceRms:Math.sqrt(diffPower/(input.length*input.numberOfChannels)),outputRms:Math.sqrt(power/(input.length*input.numberOfChannels)),rawTrace:raw.trace};
  },rate);
  assert.deepEqual(rendered.trace,{gains:[1],filters:[{type:'lowpass',frequency:1800,Q:.5}],compressors:0},'Only frozen filter and unity route gain are baked');
  assert.ok(rendered.referenceError<1e-7,'Frozen _play matches independent unity filter graph');assert.ok(rendered.rawError>.05&&rendered.differenceRms>.01,'Original unfiltered asset is rejected by DSP oracle');
  const output=pcm(rendered.channels);assert.equal(output.frames,rendered.inputFrames,'No trim, padding or time stretching');assert.equal(output.channels,rendered.inputChannels,'Preserve original decoded channel count');
  if(process.argv.includes('--verify'))assert.equal(sha(fs.readFileSync(target)),sha(output.bytes),'Re-render exactly matches shipped derived PCM');
  else{fs.writeFileSync(target,output.bytes);if(!fs.existsSync(target+'.meta'))fs.writeFileSync(target+'.meta',JSON.stringify({uuid:crypto.randomUUID()},null,2)+'\n');}
  const config=require('../../assets/Intro/Intro.json');assert.equal(config.audio.sfx_tv_cut,'Intro/Audio/sfx_tv_cut.mp3');assert.equal(config.audio.sfx_tv_cut_lowpass1800,relative);assert.equal(config.audioDsp['tv_cut:1800'],'sfx_tv_cut_lowpass1800');
  const {channels,...oracle}=rendered,report={result:'PASS',baseline:baseline.commit,provenance,toolSha256:sha(fs.readFileSync(__filename)),output:{path:relative,sha256:sha(output.bytes),bytes:output.bytes.length,format:'PCM16',sampleRate:rate,channels:output.channels,frames:output.frames,seconds:output.frames/rate,peak:output.peak,quantizationMaxError:output.quantizationError},oracle,runtime:{originalId:'tv_cut',vol:.5,stopAfter:.45,stopFade:.15,bakedGain:1,bakedCompressor:false,bakedMaster:false},negativeControls:{originalUnfilteredRejected:true,rawMaxError:rendered.rawError},browserShutdown:'CLOSED',boundary:'Frozen actual IntroAudio._play in OfflineAudioContext at unity gain; only lowpass 1800Hz/Q0.5 is baked. Original channels and decoded sample duration retained. Runtime normalization, bus/user/master gains and stop envelope remain live. Does not verify native decoding, audible Web mix, compressor parity, gameplay timing or mobile performance.'};
  await browser.close();browser=null;fs.writeFileSync(path.join(root,'docs/migration/evidence/intro-tvcut-lowpass-source.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report));
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
}
if(require.main===module)run().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={pcm};
