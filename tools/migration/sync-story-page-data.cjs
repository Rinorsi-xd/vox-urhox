const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
async function main(){
const root=path.resolve(__dirname,'../..');
const frozen=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'))).snapshot;
const target=path.join(root,'assets/UI/Outgame.json'),data=JSON.parse(fs.readFileSync(target));
const source=await import(require('node:url').pathToFileURL(path.join(frozen,'shared/story/chapter1.js')).href);
data.levels=source.STORY_LEVELS;
fs.writeFileSync(target,JSON.stringify(data));
const lines=JSON.parse(fs.readFileSync(path.join(frozen,'shared/assets/story/vo/lines.json')));
const voices={};
for(let n=1;n<=10;n++){
 const id='C-'+String(n).padStart(2,'0'),file='shared/assets/story/vo/'+id+'.mp3';
 const bytes=fs.readFileSync(path.join(frozen,file)),dest='Story/Page/'+id+'.mp3';
 fs.mkdirSync(path.join(root,'assets/Story/Page'),{recursive:true});fs.copyFileSync(path.join(frozen,file),path.join(root,'assets',dest));
 voices[id]={...lines[id],path:dest,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
}
fs.writeFileSync(path.join(root,'assets/Story/Page/Voices.json'),JSON.stringify({source:'2b169a9964645f5f346a7158bcb14447f040814a',voices}));
const portraits=path.join(root,'assets/Story/Page/Faces');fs.mkdirSync(portraits,{recursive:true});
const python='C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
for(const name of new Set(data.levels.map(l=>l.nono[0]))){
 require('node:child_process').execFileSync(python,['-c','from PIL import Image; import sys; Image.open(sys.argv[1]).convert("RGBA").save(sys.argv[2])',
  path.join(frozen,'shared/assets/intro/face',name+'.webp'),path.join(portraits,name+'.png')]);
}
console.log('Story page: all frozen level metadata and 10 original page voices synchronized');
}
main().catch(error=>{console.error(error);process.exitCode=1});
