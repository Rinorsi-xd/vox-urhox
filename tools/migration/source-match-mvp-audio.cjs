const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8')),hashes={};
function read(file){const raw=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');const sha=crypto.createHash('sha256').update(raw).digest('hex');if(sha!==baseline.files[file].sha256)throw Error('Frozen SHA mismatch: '+file);hashes[file]=sha;return raw;}
function actual(file,name,bindings){const code=read(file).replace(/^import .*;\r?\n/gm,'').replace(/export /g,'').replace(/import\.meta\.url/g,JSON.stringify('file:///D:/Rino_Project/Vox/'+file));return vm.runInNewContext(code+'\n'+name,{URL,console,Math,Float32Array,...bindings});}
let serial=0;const timers=new Map(),levels={speaking:0,musicEnabled:true,get:()=>.75,on:(kind,fn)=>{fn(.6);return()=>{};}};
const Radio=actual('shared/audio/radio.js','Radio',{levels,DEFAULT_LEVELS:{voice:.6},setTimeout:(fn,ms)=>{timers.set(++serial,{fn,ms});return serial;},clearTimeout:id=>timers.delete(id)});
const radio=Object.create(Radio.prototype);Object.assign(radio,{ctx:{currentTime:0,state:'running'},buf:{line:{duration:2}},live:new Set(),gains:new Map(),_static(){},_beep(){},_src(){}});
const speaking=[];function record(label){speaking.push({label,speaking:levels.speaking});}
const length=radio.say('line');record('start');const timer=[...timers.values()][0];timer.fn();record('natural end');radio.say('line');radio.stop();record('stop');radio.say('line');radio.fade();record('fade');radio.say('line');radio.say('line');record('replace');radio.stop();record('replacement stop');radio.say('missing');record('missing');
const musicSource=read('shared/audio/musicPlayer.js');const gainMatch=musicSource.match(/export const musicGain =[^\r\n]+/);if(!gainMatch)throw Error('musicGain source missing');
const musicGain=vm.runInNewContext(gainMatch[0].replace('export ', '')+';musicGain',{Math});
const Mvp=actual('shared/audio/mvpMusic.js','MvpMusic',{levels,musicGain,MVP_BEAT_MAP:{beats:[]},document:{hidden:false}});
const music=[];for(const volume of [0,.3,.75,1]){levels.get=()=>volume;const m=Object.create(Mvp.prototype);m.audio={paused:false,pause(){this.paused=true;}};m.sync();music.push({volume,gain:m.audio.volume,paused:m.audio.paused});}
const Sample=actual('shared/audio/samplePlayer.js','SamplePlayer',{performance:{now:()=>0}});
const sourceAudio=JSON.parse(require('node:child_process').execFileSync('node',['--experimental-vm-modules','tools/migration/source-game-audio.cjs'],{encoding:'utf8'}));
const cues=JSON.parse(fs.readFileSync('assets/Mvp/Cues.json','utf8')),samples=[];
for(const [id,cue]of Object.entries(cues))for(const strength of [-.2,0,.8,1,1.4])for(const volume of [0,.1,.65,1]){
 const nodes=[];const node=()=>{const n={gain:{value:1},pan:{value:0},playbackRate:{value:1},connect(to){return to;},start(){},stop(){}};nodes.push(n);return n;};
 const master=sourceAudio.masters.find(x=>x.volume===volume)?.gain??0;
 const context={state:'running',createBufferSource:node,createGain:node,createStereoPanner:node};
 const player=new Sample({[id]:sourceAudio.cues[id]},'',()=>{},{context,master:{gain:{value:master}}});player.buffers.set(id+'_a',{duration:1});
 player.play(id,{gainScale:strength});samples.push({id,strength,volume,gain:nodes[1].gain.value*master,bus:sourceAudio.cues[id].bus,sourceCueGain:sourceAudio.cues[id].gain});
 if(Math.abs(cue.gain-sourceAudio.cues[id].gain)>1e-12)throw Error('Imported cue differs: '+id);
}
for(const [file,sha]of Object.entries(sourceAudio.hashes)){const raw=read(file);if(sha!==crypto.createHash('sha256').update(raw.replace(/\r\n/g,'\n')).digest('hex'))throw Error('Source module SHA mismatch: '+file);}
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceHashes:hashes,radio:{length,timerSeconds:timer.ms/1000,speaking},music,samples}));
