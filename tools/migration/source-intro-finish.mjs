import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const file='three/src/intro/intro.js';
const source=fs.readFileSync(path.join(baseline.snapshot,file),'utf8');
const hash=createHash('sha256').update(source).digest('hex');
if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift');
const finish=source.slice(source.indexOf('\t_finish() {'),source.indexOf('\n\t// ── 每帧'));
const skip=source.slice(source.indexOf('\t_skipNow() {'),source.indexOf('\n\t_key( e )'));
const trace=[];
const context=vm.createContext({URL,location:{href:'https://example.test/?intro=1'},
 history:{replaceState(){trace.push('url');}},window:{removeEventListener(){}},
 document:{body:{classList:{remove(){trace.push('body');}}}},Skip:class extends Error{}});
vm.runInContext('globalThis.Intro=class {'+finish+skip+'}',context);
let resolveAnimation,animation;
const I=new context.Intro();
Object.assign(I,{active:true,stage:'reality',time:10,log:[],audio:{fadeOutAll(t){trace.push(['audio',t]);}},
 _restoreLights(){trace.push('lights');},_clearProps(){trace.push('props');},_tv(){},drive:{active:true,exit(){trace.push('drive');}},
 pipeline:{setScene(){trace.push('scene');}},camera:{updateProjectionMatrix(){}},garage:{cameraFar:500,welcome(){trace.push('welcome');}},
 view:{root:{}},editor:{suspend(){trace.push('editor');},bp:{}},rig:{apply(){trace.push('camera');}},mark(){trace.push('end');},
 root:{animate(frames,options){animation={frames,options};return {finished:new Promise(resolve=>{resolveAnimation=resolve;})};},remove(){trace.push('remove');}},
 shell:{go(){trace.push('home');},tutorial:{start(){trace.push('tutorial');}}}});
I._finish();
const before=[...trace];
I._finish();
if(JSON.stringify(trace)!==JSON.stringify(before))throw Error('Source finish is not idempotent');
if(trace.includes('home')||trace.includes('remove'))throw Error('Source finishes before animation');
resolveAnimation();await Promise.resolve();
const after=[...trace];
I.skipping=false;I.waits=[{rej(){throw Error('reality skip should be ignored');}}];I._skipNow();
if(I.skipping)throw Error('Source allows reality skip');
process.stdout.write(JSON.stringify({baseline:{branch:baseline.branch,commit:baseline.commit},sourceHashes:{[file]:hash},
 animation,before,after,realitySkipIgnored:true}));
