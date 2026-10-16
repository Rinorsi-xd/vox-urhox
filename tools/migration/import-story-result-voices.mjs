import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {Collect} from './story-result-voice-source.mjs';
const root=path.resolve(import.meta.dirname,'../..');const source=await Collect();
const dest=path.join(root,'assets/Story/Mission/ResultVoices.json');
const previous=fs.existsSync(dest)?JSON.parse(fs.readFileSync(dest)):{};
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const voices={};
for(const quote of source.quotes){
 if(!quote.id)continue;
 const relative=`shared/assets/story/vo/${quote.id}.mp3`;
 const output=path.join(root,'assets/Story/Mission',quote.id+'.ogg');
 const pathInGame=`Story/Mission/${quote.id}.ogg`;
 const sha=source.source.files[relative];
 if(!fs.existsSync(output)||previous.voices?.[quote.id]?.sha256!==sha){
  if(process.argv.includes('--check'))throw Error('Missing or stale result recording '+quote.id);
  if(!process.env.VOX_FFMPEG)throw Error('Set VOX_FFMPEG to a libvorbis-capable ffmpeg');
  execFileSync(process.env.VOX_FFMPEG,['-v','error','-y','-i',path.join(source.snapshot,relative),'-ac','1','-ar','24000','-c:a','libvorbis','-q:a','4',output],{windowsHide:true});
 }
 voices[quote.id]={path:pathInGame,text:source.index[quote.id].text,sha256:sha,derivedSha256:hash(fs.readFileSync(output))};
}
const result={source:source.source,quotes:source.quotes,voices};
const bytes=JSON.stringify(result);
if(process.argv.includes('--check')){
 if(fs.readFileSync(dest,'utf8')!==bytes)throw Error('Result recording registry differs from frozen source');
}else if(!fs.existsSync(dest)||fs.readFileSync(dest,'utf8')!==bytes){
 fs.writeFileSync(dest+'.import-tmp',bytes);fs.renameSync(dest+'.import-tmp',dest);
}
console.log(JSON.stringify({result:'PASS',voices:Object.keys(voices).length,authoredQuotes:source.quotes.length,bytes:Object.values(voices).reduce((n,v)=>n+fs.statSync(path.join(root,'assets',v.path)).size,0)}));
