import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {createHash} from 'node:crypto';
const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json'));
const sourceHashes={};
function source(file){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,file));
 const sha=createHash('sha256').update(bytes).digest('hex');
 if(sha!==baseline.files[file].sha256)throw Error(`Source drift: ${file}`);
 sourceHashes[file]=sha;return bytes.toString('utf8');
}
const intro=source('three/src/intro/intro.js'),story=source('three/src/intro/introStory.js');
const flash=story.slice(story.indexOf('\tflash( color ='),story.indexOf('\n\tshakeDom('));
const cut=intro.slice(intro.indexOf('\tcut( color ='),intro.indexOf('\n\t// ── 3D'));
const decided=intro.slice(intro.indexOf("\t\tthis.mark( 'decided' );"),intro.indexOf("\n\t\tawait this.say( 'n07'"));
const mechanic=intro.slice(intro.indexOf("\t\tw = this.words( '战地机修师！'"),intro.indexOf("\n\t\tawait this.say( 'n15'"));
const events=[];const el=name=>({style:{setProperty(){}},remove(){},animate(frames,options){events.push({name,color:this.style.background,frames,options});}});
const context=vm.createContext({hero:el('hero'),idle:el('idle'),chr:el('chr'),speed:el('speed'),hold:el('hold'),D:el('D'),w:null});
vm.runInContext(`globalThis.Host=class {${flash}\n${cut}};globalThis.decided=function(){${decided}};globalThis.mechanic=function(){${mechanic}};`,context);
const host=new context.Host();Object.assign(host,{L:{flash:el('flash')},audio:{sfx(){},playMusic(){}},mark(){},words(){return {};}});
host.cut();const cutEvents=events.splice(0);
context.decided.call(host);const decidedEvents=events.splice(0);
context.mechanic.call(host);const mechanicEvents=events.splice(0);
host.flash('#ff3a2a',260,.6);const wagesEvents=events.splice(0);
if(!intro.includes("this.fade( this.L.black, 0.7, 500 );"))throw Error('Missing source motto fade');
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceHashes,cut:cutEvents,decided:decidedEvents,mechanic:mechanicEvents,wages:wagesEvents,motto:{to:.7,duration:500,easing:'ease-in-out'}}));
