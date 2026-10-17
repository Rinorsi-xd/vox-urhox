const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),baseline=require('../../docs/migration/outgame-baseline.json'),name='shared/ui/matchHud.js';
const bytes=fs.readFileSync(path.resolve(root,baseline.snapshot,name)),sha=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(sha,baseline.files[name].sha256);
const code=bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/export class /g,'class ');
const MatchHud=vm.runInNewContext(`(()=>{${code};return MatchHud;})()`,{escapeHtml:s=>String(s),avatarUrl:()=>'',setTimeout:()=>{}});
const cases=[];
for(const [id,en,size]of [['elimination','ELIMINATION',3],['conquest','CONQUEST',4],['escort','ESCORT',4]]){
 const hud=Object.assign(Object.create(MatchHud.prototype),{mode:{id,name:'原模式',en,size}}),board={innerHTML:''};hud.$=()=>board;
 const rows=hud._rows([],null),headers=[...rows.matchAll(/<span(?: [^>]*)?>(.*?)<\/span>/g)].map(m=>m[1]);
 hud._board([],{mode:id,round:1,half:1,state:'live',timeLeft:120,score:{blue:0,red:0}});
 const subtitle=board.innerHTML.match(/<div class="md">.*?<small>(.*?)<\/small>/s)[1];
 cases.push({id,en,size,headers,subtitle});
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,source:name,sourceSha256:sha,cases}));
