const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const name='three/src/drive/testDrive.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name)),sha=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha!==baseline.files[name].sha256)throw Error('Frozen source drift');
const source=bytes.toString('utf8'),start=source.indexOf('onLegCourse: name => {')+'onLegCourse: name => {'.length,end=source.indexOf('} } );',start);
if(start<24||end<start)throw Error('Actual course callback boundary missing');
const callback=vm.runInNewContext('(function(name){'+source.slice(start,end)+'})');
const cases=[];
for(const active of [false,true])for(const name of ['节足山坡','节足抓墙','missing'])for(const available of [false,true]){
 const trace=[],owner={active,layout:{teleports:available?[{name:'节足山坡'},{name:'节足抓墙'}]:[]},_spawn(spot){trace.push(['spawn',spot.name]);},ui:{toast(...a){trace.push(['toast',...a]);}},resumeInput(){trace.push(['resume']);}};
 callback.call(owner,name);cases.push({active,name,available,trace});
}
const out=path.join(root,'.tmp/source-practice-course.json');fs.writeFileSync(out,JSON.stringify({commit,sourceHashes:{[name]:sha},cases},null,2)+'\n');console.log(JSON.stringify({out,cases:cases.length}));
