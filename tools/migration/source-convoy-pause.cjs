'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
function check(){
 const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8')),sources={},hashes={};
 for(const file of ['three/src/drive/testDrive.js','three/src/battle/storyMission.js','shared/ui/shell.js','three/src/main.js']){
  const bytes=fs.readFileSync(path.join(baseline.snapshot,file));hashes[file]=crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(hashes[file],baseline.files[file].sha256,file);sources[file]=bytes.toString();
 }
 const drive=sources['three/src/drive/testDrive.js'],mission=sources['three/src/battle/storyMission.js'],shell=sources['shared/ui/shell.js'];
 const begin=drive.indexOf('\tupdate( dt, time ) {'),end=drive.indexOf('\t\t// Rest rewards remain audible',begin);
 assert(begin>0&&end>begin);const update=drive.slice(begin,end)+'\n}\n';
 const getter=mission.match(/get paused\(\) \{ return this\.finished; \}/)?.[0];assert(getter);
 const menuStart=shell.indexOf('\tpauseMenu() {'),menuEnd=shell.indexOf("\t// 'home'",menuStart);assert(menuStart>0&&menuEnd>menuStart);
 let steps=0,before=0,after=0,playerSteps=0,pausedUi=0,locked=true,modal=0,seenCommand;
 const context=vm.createContext({PHYSICS_DT:1/60,sfx:{stopDriving(){},consumeDamage(){},play(){}},
  readDriveCommand:()=>({throttle:1,steer:1,climb:1,strafe:1,cutLift:true,handbrake:true,jump:true}),
  cameraListener:()=>({}),touchUi:()=>false,icon:()=>'',document:{pointerLockElement:{},exitPointerLock(){locked=false}}});
 const prototype=vm.runInContext('({'+update+'})',context);
 const modePrototype=vm.runInContext('({'+getter+'})',context);
 const controller=Object.create(modePrototype);Object.assign(controller,{finished:false,beforeStep(){before++},afterStep(){after++},pausedUpdate(){pausedUi++}});
 const copy={copy(){}};const car={telemetry:{legJumped:false}};
 const session={modeController:controller,vehicle:car,input:{controlling:false},cam:{yaw:0,pitch:0},acc:0,
  player:{flush(){},step(dt,command){playerSteps++;seenCommand={...command}},fire(){return[]}},
  sim:{viewEvents:[],step(){steps++}},camera:{position:{x:0,y:0,z:0}},
  _syncPlayer(){},_updateAim(){},_saveCur(){},prev:{p:copy,q:copy},cur:{p:{},q:{}},
  collisionAudio:{beforeStep(){},afterStep(){return[]}},stepFx:[]};
 prototype.update.call(session,1/60,1);
 assert.deepEqual([steps,before,after,playerSteps],[1,1,1,1]);
 assert.deepEqual(seenCommand,{throttle:0,steer:0,climb:0,strafe:0,cutLift:false,handbrake:false,jump:false});
 controller.finished=true;prototype.update.call(session,1/60,2);
 assert.deepEqual([steps,before,after,playerSteps,pausedUi],[1,1,1,1,1]);
 const menu=vm.runInContext('({'+shell.slice(menuStart,menuEnd)+'})',context);
 const shellState={screen:'home',editor:{},ui:{openModal(){modal++;return{querySelectorAll(){return[]}}}}};
 menu.pauseMenu.call(shellState);assert.equal(locked,false);assert.equal(modal,1);assert.equal(controller.finished,true);
 assert(!Object.hasOwn(shellState,'paused'));assert(!Object.hasOwn(shellState,'active'));
 const line=(text,offset)=>text.slice(0,offset).split('\n').length;
 return {status:'PASS',baseline:{branch:baseline.branch,commit:baseline.commit},hashes,
  checks:{neutralInputActualUpdateSteps:steps,neutralCommand:seenCommand,finishedEarlyReturn:true,menuOnlyReleasesPointer:true},
  locations:{driveUpdate:line(drive,begin),storyPausedGetter:line(mission,mission.indexOf(getter)),shellPauseMenu:line(shell,menuStart),
   mainDriveUpdate:line(sources['three/src/main.js'],sources['three/src/main.js'].indexOf('else if ( drive.active ) drive.update'))},
  boundary:'Executed the frozen actual update method prefix through fixed-step completion with native-free adapters, actual story paused getter and actual pauseMenu. Shows pointer-unlocked neutral simulation, and finished early-return. Does not emulate browser, physics, real audio or full mission.'};
}
module.exports={check};
if(require.main===module){const report=check();const file=process.argv[2];if(file)fs.writeFileSync(path.resolve(file),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report))}
