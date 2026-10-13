const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const src=fs.readFileSync(path.join(baseline.snapshot,'three/src/drive/testDrive.js'),'utf8');
const begin=src.indexOf('\t_fireState( g, mark, dist ) {'),end=src.indexOf('\n\t// 准星对着的敌人',begin);
if(begin<0||end<0)throw Error('Frozen source fire-state method missing');
const method=src.slice(begin,end).trim();const body=method.slice(method.indexOf('{')+1,method.lastIndexOf('}'));
const fire=vm.runInNewContext('(function(g,mark,dist){'+body+'})');
const cases=[];
for(const kind of ['laser','mg','sniper','missile'])for(const ready of [0,.25,.8,1])for(const status of ['idle','fire','offline','limited','blocked','far','windup','reload','volley','poor','locked','locking']){
 const stats={range:250,...(kind==='mg'?{spinUp:.6}:kind==='sniper'?{windup:1.4}:{})};
 const group={kind,weapons:[{stats,windup:status==='windup'?.6:0}]};
 const lock={energyOk:status!=='poor',count:3,tubes:6,progress:status==='locking'?.4:0,locked:status==='locked',cooling:status==='reload',reload:.35,firing:status==='volley'};
 const wpn={offline:status==='offline',energy:17,energyMax:100,blocked:status==='limited'?1:0,readiness:()=>ready,lockInfo:()=>lock};
 const args={kind,ready,status,stats,windup:group.weapons[0].windup,lock};
 const context={weapons:wpn,firing:['fire','limited','blocked','windup'].includes(status),aimRef:status==='far'?{}:null,player:{}};
 const expected=fire.call(context,group,status==='blocked'?'blocked':'ok',status==='far'?300:50);
 cases.push({args,expected});
}
fs.writeFileSync(path.join(root,'tools/migration/source-reticle.json'),JSON.stringify({commit:baseline.commit,cases},null,2));
console.log('Executed frozen H5 fire state: '+cases.length+' fixtures');
