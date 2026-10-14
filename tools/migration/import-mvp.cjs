// Derived assets only: frozen source audio, beat data and shader wrappers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const hashes={};
for(const name of ['three/src/battle/mvpShow.js','shared/audio/mvpMusic.js','shared/audio/mvpBeatMap.js','shared/assets/audio/mvp/bangyou-dj.mp3']){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,name)),hash=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hash!==baseline.files[name]?.sha256)throw Error('Frozen MVP source changed: '+name);hashes[name]=hash;
}
const beats=fs.readFileSync(path.join(baseline.snapshot,'shared/audio/mvpBeatMap.js'),'utf8').match(/export const MVP_BEAT_MAP = (\{.*\});/)[1];
fs.writeFileSync(path.join(root,'assets/Mvp/Beats.json'),beats);
fs.copyFileSync(path.join(baseline.snapshot,'shared/assets/audio/mvp/bangyou-dj.mp3'),path.join(root,'assets/Mvp/music.mp3'));
const cueText=fs.readFileSync(path.join(baseline.snapshot,'shared/audio/rewardCues.js'),'utf8');
const trimText=fs.readFileSync(path.join(baseline.snapshot,'shared/audio/mixTrim.js'),'utf8'),cues={};
for(const id of ['supply_open','wave_clear','loot_drop','supply_choose']){
 const row=cueText.match(new RegExp(id+': \\{([^}]+)'))[1],variant=row.match(/variant: '([^']+)'/)[1];
 const gain=Number(row.match(/gain: ([.\d]+)/)[1]),trim=Number(trimText.match(new RegExp(id+': ([.\\d]+)'))[1]);
 const file=id+'_'+variant+'.wav',source='shared/assets/audio/rewards-07/'+file;
 const bytes=fs.readFileSync(path.join(baseline.snapshot,source));if(crypto.createHash('sha256').update(bytes).digest('hex')!==baseline.files[source]?.sha256)throw Error('Frozen cue changed');
 fs.writeFileSync(path.join(root,'assets/Mvp',file),bytes);cues[id]={path:'Mvp/'+file,gain:gain*10**(trim/20)};
}
fs.writeFileSync(path.join(root,'assets/Mvp/Cues.json'),JSON.stringify(cues));
const dir=path.join(root,'assets/Shaders/BLGL'),variants=[];
function expand(file,seen=new Set()){
 if(seen.has(file))return '';seen.add(file);
 return fs.readFileSync(file,'utf8').replace(/#include "([^"]+)"/g,(_,p)=>expand(p.startsWith('res://')?path.join(root,'assets',p.slice(6)):path.resolve(path.dirname(file),p),seen));
}
for(const name of fs.readdirSync(dir).filter(n=>/^(Vox|Livery).*\.shader$/.test(n))){
 let code=expand(path.join(dir,name));
 if(/depth_draw_never|blend_add/.test(code))continue;
 code=code.replace(/#include "([^"]+)"/g,(_,p)=>'#include "res://Shaders/BLGL/'+p+'"');
 const deformation='\nvec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;\nVERTEX=(inverse(MODEL_MATRIX)*vec4(mvp_deform(world),1.0)).xyz;\n';
 const vertex=code.match(/void vertex\s*\(\s*\)\s*\{/);
 if(vertex){
  let end=vertex.index+vertex[0].length,depth=1;
  while(depth&&end<code.length){if(code[end]==='{')depth++;else if(code[end]==='}')depth--;end++;}
  if(depth)throw Error('Unbalanced vertex source '+name);
  code=code.slice(0,end-1)+deformation+code.slice(end-1);
 }else code+='\nvoid vertex(){'+deformation+'}\n';
 code=code.replace('shader_type spatial;','shader_type spatial;\n#include "../Deform.shaderinc"');
 fs.mkdirSync(path.join(dir,'Mvp/Vehicle'),{recursive:true});fs.writeFileSync(path.join(dir,'Mvp/Vehicle',name),code);variants.push(name);
}
fs.writeFileSync(path.join(root,'assets/Mvp/VehicleShaders.json'),JSON.stringify(variants));
fs.writeFileSync(path.join(root,'docs/migration/evidence/mvp-source.json'),JSON.stringify({baseline:baseline.commit,hashes,variants,beatCount:JSON.parse(beats).beats.length},null,2));
console.log('Imported frozen MVP music, beat map and '+variants.length+' material wrappers');
