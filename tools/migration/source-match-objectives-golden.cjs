const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
class Vec{set(x,y,z){this.x=x;this.y=y;this.z=z;return this;} project(cam){this.x=this.x/100;this.y=this.y/100;this.z=cam.behind?2:0;return this;}}
const box=vm.createContext({THREE:{Vector3:Vec},innerWidth:1920,innerHeight:1080});
const code=fs.readFileSync(path.join(baseline.snapshot,'three/src/battle/matchSession.js'),'utf8').replace(/^import .*;\r?\n/gm,'').replace(/export (class|function) /g,'$1 ');
const Match=vm.runInContext(`(()=>{${code};return MatchSession;})()`,box);
const cases=[];
for(const [w,h] of [[1920,1080],[2400,1080],[840,378],[1605,388]])for(const behind of [false,true])for(const x of [-180,-30,0,80,200])for(const alive of [false,true]){
 box.innerWidth=w;box.innerHeight=h;
 const player={alive,pos:[x,0,0],spec:{bounds:{radius:6}}};
 const points=[{id:'A',pos:[0,0,0],radius:22},{id:'B',pos:[200,40,300],radius:22}];
 const states=[{id:'A',v:.45,owner:null,contested:false,count:{blue:1,red:0}},{id:'B',v:-.2,owner:'red',contested:true,count:{blue:1,red:2}}];
 const session=Object.assign(Object.create(Match.prototype),{drive:{camera:{behind},player},rules:{state:'live',points:states},mode:'conquest',mx:{points}});
 cases.push({w,h,behind,player,points,states,expected:session._objectives()});
}
process.stdout.write(JSON.stringify(cases));
