import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const file=path.join(baseline.snapshot,'shared/story/tutorial.js');
const {TUTORIAL,FLOWS}=await import(pathToFileURL(file));
const conditions=['choose','edit','bag','pick','place','save','back','battle','story','go','leave'];
for(const step of TUTORIAL) {
 if(step.until&&!conditions.includes(step.id))throw Error('Untranslated tutorial condition '+step.id);
 if(step.begin&&step.id!=='place')throw Error('Untranslated tutorial begin '+step.id);
 if(step.hide&&step.id!=='debrief')throw Error('Untranslated tutorial hide '+step.id);
}
const voices={},index=JSON.parse(fs.readFileSync(path.join(baseline.snapshot,'shared/assets/story/vo/lines.json')));
const norm=s=>s.replace(/[^\p{Script=Han}A-Za-z0-9]/gu,'');
for(const step of TUTORIAL)for(const line of step.lines){
 const voice=Object.entries(index).find(([id,v])=>v.text.some(text=>norm(text)===norm(line[1])));
 if(!voice)continue;const [id,v]=voice;if(voices[id])continue;
 const input=path.join(baseline.snapshot,'shared/assets/story/vo',id+'.mp3'),output=path.join(root,'assets/Story/Tutorial',id+'.ogg');
 fs.mkdirSync(path.dirname(output),{recursive:true});
 if(!fs.existsSync(output)){if(!process.env.VOX_FFMPEG)throw Error('Set VOX_FFMPEG');execFileSync(process.env.VOX_FFMPEG,['-v','error','-y','-i',input,'-ac','1','-ar','24000','-c:a','libvorbis','-q:a','4',output],{windowsHide:true});}
 voices[id]={path:'Story/Tutorial/'+id+'.ogg',text:v.text,sha256:createHash('sha256').update(fs.readFileSync(input)).digest('hex')};
}
const data={voices,source:{branch:baseline.branch,commit:baseline.commit,scriptSha256:createHash('sha256').update(fs.readFileSync(file)).digest('hex')},
 steps:TUTORIAL.map(s=>({...s,until:s.until?s.id:undefined,begin:s.begin?'partCount':undefined,hide:s.hide?'drive':undefined})),flows:FLOWS};
fs.writeFileSync(path.join(root,'assets/UI/Tutorial.json'),JSON.stringify(data));
console.log(JSON.stringify({steps:data.steps.length,voices:Object.keys(voices).length,flows:Object.keys(FLOWS),source:data.source}));
