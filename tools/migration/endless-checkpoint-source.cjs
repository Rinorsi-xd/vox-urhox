// Execute the frozen H5 persistence method with successful and failed storage.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const name='three/src/battle/endlessSession.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name));
const digest=crypto.createHash('sha256').update(bytes).digest('hex');
if(digest!==baseline.files[name].sha256)throw Error('Frozen source drift');
const cases=[];
for(const state of ['rest','combat','editing','countdown','over'])for(const fail of [false,true]){
 const notices=[],writes=[];
 const c=vm.createContext({ENDLESS:{runKey:'checkpoint'},window:{dispatchEvent(){}},Event:class Event{},localStorage:{setItem(key,value){writes.push({key,value:JSON.parse(value)});if(fail)throw Error('storage unavailable');}}});
 vm.runInContext(bytes.toString('utf8').replace(/^import .*;\r?\n/gm,'').replace(/^export /gm,'')+'\nglobalThis.Session=EndlessSession;',c);
 const s=Object.create(c.Session.prototype);
 Object.assign(s,{run:{state,save:()=>({wave:4,score:350})},drive:{ui:{toast:(text,tone)=>notices.push({text,tone})}}});
 s.persist();cases.push({state,fail,writes,notices});
}
const result={commit,sourceHashes:{[name]:digest},cases};
if(process.argv.includes('--stdout'))process.stdout.write(JSON.stringify(result));
else console.log(JSON.stringify({result:'PASS',cases:cases.length}));
