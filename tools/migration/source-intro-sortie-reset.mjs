import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const hashes={};
function source(file){
 const text=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
 const hash=createHash('sha256').update(text).digest('hex');
 if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift: '+file);
 hashes[file]=hash;return text;
}
const intro=source('three/src/intro/intro.js');
const drive=source('three/src/drive/testDrive.js');
const introKey=intro.slice(intro.indexOf('\t_key( e ) {'),intro.indexOf('\n\t_buildDom()'));
const driveKey=drive.slice(drive.indexOf('\t_key( e ) {'),drive.indexOf('\n\t// R 重置'));
const ctx=vm.createContext({isTyping:()=>false,performance:{now:()=>1000}});
vm.runInContext('globalThis.Intro=class{'+introKey+'};globalThis.Drive=class{'+driveKey+'};',ctx);
const cases=[];
for(const code of ['KeyR','Escape','KeyT','Backspace']){
 const calls=[];const I=new ctx.Intro();I.playing=true;
 const d=new ctx.Drive();d.active=true;d._beginReset=()=>calls.push('reset');
 d.exit=()=>calls.push('exit');d.input={locked:true};
 const e={code,type:'keydown',repeat:false,stopPropagation(){this.stopped=true;},preventDefault(){},target:{closest:()=>false}};
 I._key(e);if(!e.stopped)d._key(e);
 cases.push({code,stopped:!!e.stopped,calls});
}
if(cases[0].calls.join()!=='reset'||cases.slice(1).some(c=>!c.stopped||c.calls.length))throw Error('Source route mismatch');
const cine=intro.slice(intro.indexOf('\t\tthis.cine = {'),intro.indexOf('\n\t\td.modeController = this.cine;'));
if(/\bkey\s*:/.test(cine))throw Error('Cinematic owns keyboard; adapter must include it');
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},hashes,cases}));
