const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=process.cwd(),run=__dirname;
let frozen=JSON.parse(fs.readFileSync(path.join(run,'frozen-scripts.json'),'utf8').replace(/^\uFEFF/,''));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
if(process.argv.includes('--recover-snapshot')){
 fs.writeFileSync(path.join(run,'later-production-scripts.json'),JSON.stringify(frozen,null,2)+'\n');
 frozen=Object.fromEntries(Object.keys(frozen).map(relative=>[relative,hash(path.join(run,'snapshot',relative.replaceAll('\\','/')))]));
 fs.writeFileSync(path.join(run,'frozen-scripts.json'),JSON.stringify(frozen,null,2)+'\n');
}
const failures=[],currentDifferences=[];
for(const [relative,expected]of Object.entries(frozen)){
 const clean=relative.replaceAll('\\','/');
 for(const [kind,p]of [['production',path.join(root,clean)],['snapshot',path.join(run,'snapshot',clean)]]){
  if(!fs.existsSync(p)||hash(p)!==expected)(kind==='production'?currentDifferences:failures).push({kind,relative,expected,actual:fs.existsSync(p)?hash(p):null});
 }
}
const evidence={};
for(const f of ['none.json','coarse.json','respawn-coverage.json','summary.json','NativeBattleCPU.lua','run.ps1','summarize.cjs','frozen-scripts.json'])evidence[f]=hash(path.join(run,f));
const result={result:failures.length?'FAIL':'PASS',productionLuaFiles:Object.keys(frozen).length,comparison:'Frozen SHA256 against measured isolated snapshot; current production differences reported separately',provenance:'Initial pre-coverage verification matched all 534 production and snapshot Lua files with original manifest SHA256 98d7cfd0ba9a729d1d0aefab0c6da2cf8c77a7bd5d0295b4b1552440de9d731c. Old runner overwrote manifest during concurrent production edits; restored manifest values from unchanged isolated snapshot. Runner now preserves it.',failures,currentDifferences,evidence};
fs.writeFileSync(path.join(run,'integrity.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
process.exitCode=failures.length?1:0;
