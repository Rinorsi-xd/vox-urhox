// Execute original station/center method bodies and CameraRig, source read-only.
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const baseline=JSON.parse(fs.readFileSync(new URL('../../docs/migration/outgame-baseline.json',import.meta.url)));
const source=baseline.snapshot;
const hashes={};
async function load(file){
 const bytes=fs.readFileSync(path.join(source,file));
 const hash=crypto.createHash('sha256').update(bytes).digest('hex');
 const expected=baseline.files[file];
 if(!expected||expected.sha256!==hash)throw Error('Frozen source changed: '+file);
 hashes[file]=hash;
 return import(pathToFileURL(path.join(source,file)).href);
}
const {CameraRig}=await load('shared/controls/cameraRig.js');
const {Vector3}=await load('shared/core/math.js');
const {CELL}=await load('shared/config.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const {buildRaceCar,buildDrillTank}=await load('shared/build/prefab.js');
function method(file,name){
 const bytes=fs.readFileSync(path.join(source,file));
 const text=bytes.toString('utf8').replace(/\r\n/g,'\n');
 hashes[file]=crypto.createHash('sha256').update(bytes).digest('hex');
 if(baseline.files[file]?.sha256!==hashes[file])throw Error('Frozen source changed: '+file);
 const start=text.indexOf('\n\t'+name+'('),end=text.indexOf('\n\t}\n',start);
 if(start<0||end<0)throw Error('Source method not found '+name);
 return new Function('Vector3','CELL','return class {'+text.slice(start,end+4)+'}')(Vector3,CELL).prototype[name];
}
const center=method('shared/build/editor.js','_carCenter');
const station=method('shared/ui/shell.js','_station');
const limit={x:28.5,z0:-32.5,z1:34.5,y0:.3,y1:30};
const variants=[['race',buildRaceCar(new Blueprint())],['tianyuan',buildDrillTank(new Blueprint())],['empty',new Blueprint()]];
const cases=[];
for(const [name,bp] of variants){
 const stats=bp.stats(),input={mouse:[0,0],consumeMouse(){const m=this.mouse;this.mouse=[0,0];return m;}};
 const rig=new CameraRig(input,{fov:48,onPose(){}});rig.maxDist=60;rig.panMaxY=20;rig.roomLimit=limit;
 const ed={rig,diag:{stats},_carCenter:center};
 const frames=[];
 function record(action,dt,extra={}){
  rig.update(dt);frames.push({action,dt,...extra,pos:rig.position.toArray(),target:rig.target.toArray(),
    yaw:180-rig.orbit.cur.theta*180/Math.PI,pitch:90-rig.orbit.cur.phi*180/Math.PI,dist:rig.orbit.cur.dist,
    forward:rig.forward.toArray(),spin:rig.autoSpin,flight:!!rig.flight});
 }
 for(const tab of ['hangar','battle','livery','workshop','shop','hangar']){
  station.call({editor:ed},tab);
  record('tab',.016,{tab});
  for(const dt of [.049,.13,.13,.13,.13,.065,.05,.1])record('step',dt);
 }
 rig.beginDrag(2,false);input.mouse=[40,-15];record('rotate',1/60,{dx:40,dy:-15});rig.endDrag();
 rig.zoom(-100);record('zoom',1/60,{wheel:1});
 rig.beginDrag(1,false);input.mouse=[-80,25];record('pan',1/30,{dx:-80,dy:25});rig.endDrag();
 for(let i=0;i<10;i++)record('step',.1);
 station.call({editor:ed},'shop');record('tab',.22,{tab:'shop'});
 station.call({editor:ed},'battle');record('tab',.08,{tab:'battle'});
 rig.beginDrag(2,false);record('rotate',.08,{dx:0,dy:0});rig.endDrag();record('step',.5);
 // editor._pointerDown maps homepage left and right buttons to rotate/pan.
 rig.beginDrag(2,false);input.mouse=[-60,35];record('left',.1,{dx:-60,dy:35});rig.endDrag();record('step',.1);
 // Max zoom reaches room walls. Panning must use the clamped view basis.
 rig.zoom(10000);record('zoom',1,{wheel:-100});record('step',1);
 rig.beginDrag(1,false);input.mouse=[120,-70];record('pan',.1,{dx:120,dy:-70});rig.endDrag();record('step',.1);
 // Shift is sampled at drag start; changing it mid-drag does not change mode.
 rig.beginDrag(2,true);input.mouse=[25,15];record('shiftPan',.1,{dx:25,dy:15,shift:true});
 input.mouse=[25,15];record('shiftPan',.1,{dx:25,dy:15,shift:false});rig.endDrag();record('step',.1);
 rig.beginDrag(2,false);input.mouse=[20,20];record('rotate',.1,{dx:20,dy:20});
 input.mouse=[20,20];record('rotate',.1,{dx:20,dy:20,shift:true});rig.endDrag();record('step',.1);
 cases.push({name,stats,frames});
}
fs.writeFileSync(new URL('source-home-camera.json',import.meta.url),JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,limit,cases},null,2));
console.log('Original H5 station and orbit frames: '+cases.reduce((n,c)=>n+c.frames.length,0));
