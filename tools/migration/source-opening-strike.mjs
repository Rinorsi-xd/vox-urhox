import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const name='three/src/intro/introSortie.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const hash=createHash('sha256').update(bytes).digest('hex');
if(hash!==baseline.files[name].sha256)throw Error('Frozen sortie source drift');
const source=bytes.toString('utf8');
const begin=source.indexOf('const me = [ ...d.player.pos ];');
const end=source.indexOf("I.audio.sfx( 'laser_big'",begin);
if(begin<0||end<begin)throw Error('Missing original post-lock beam construction');
const block=source.slice(begin,end);
const cases=[];
for(const speed of [0,2,10,25]){
 const point=[62+speed*1.8,2,-176+speed*1.8],calls=[];
 const context=vm.createContext({d:{player:{pos:point},scene3:{}},SkyBeam:class{
  aim(from,to,radius){calls.push({from,to,radius});}
 }});
 vm.runInContext('let beam;'+block,context);
 cases.push({speed,fireAt:1.8,point,beam:calls[0]});
}
const cameraName='three/src/intro/intro.js',cameraBytes=fs.readFileSync(path.join(baseline.snapshot,cameraName));
const cameraHash=createHash('sha256').update(cameraBytes).digest('hex');
if(cameraHash!==baseline.files[cameraName].sha256)throw Error('Frozen intro camera source drift');
const cameraSource=cameraBytes.toString('utf8');
const cameraMethod=cameraSource.slice(cameraSource.indexOf('\tcamMove( {'),cameraSource.indexOf('\n\t_skipNow()',cameraSource.indexOf('\tcamMove( {')));
const cameraCases=[];
for(const wait of [2.2,10,30]){
 const pose={value:[],set(...p){this.value=p;},toArray(){return [...this.value];}};
 const look={value:[],set(...p){this.value=p;}};
 const ground=(x,z)=>x*.01-z*.02;
 const I={cam:{pos:pose,look},clearCam:p=>p,clearTasks(){},task(fn){this.fn=fn;}};
 const context=vm.createContext({I,ground,d:{player:{pos:[62,ground(62,-176)+1.5,-176]}},at:{yaw:0},playing:true});
 const mathLines=cameraSource.split('\n').filter(line=>line.startsWith('const ease =')||line.startsWith('const lerp =')||line.startsWith('const lerp3 ='));
 vm.runInContext(mathLines.join('\n')+'\nI.camMove=function'+cameraMethod.trim().slice('camMove'.length),context);
 const briefLines=source.split('\n').filter(line=>line.includes('const look0 =')||line.includes('I.task( ( k, dt, t ) => { I.cam.pos.set'));
 vm.runInContext(briefLines.join('\n'),context);I.fn(0,1/60,wait);
 const from=pose.toArray();
 const countdown=source.slice(source.indexOf('const p = d.player.pos, f ='),source.indexOf("\n\t\tfor ( const n of [ '3'",source.indexOf('const p = d.player.pos, f =')));
 vm.runInContext(countdown,context);
 const frames=[];
 for(const age of [0,.45,.9,1.35,1.8]){I.fn(age/1.8);frames.push({age,position:pose.toArray(),look:[...look.value],fov:I.cam.fov});}
 cameraCases.push({wait,from,frames});
}
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes:{[name]:hash,[cameraName]:cameraHash},cameraCases,
 boundary:'Exact frozen post-lock beam construction, brief camera task, countdown setup, camMove method and easing statements; controlled player/SkyBeam/camera adapters. Timing boundary 1.8s is authored source, not a new native measurement.',cases}));
