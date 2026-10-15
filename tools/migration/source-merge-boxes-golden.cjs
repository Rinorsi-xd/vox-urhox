const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const commit='b276064942ae09c0227ec28d4cfda1d5ff006455';
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/baselines',commit+'.json'),'utf8'));
const inputs={};
function read(name){const bytes=fs.readFileSync(path.join(baseline.snapshot,name));const sha=crypto.createHash('sha256').update(bytes).digest('hex');if(sha!==baseline.files[name].sha256)throw Error('Frozen input changed '+name);inputs[name]=sha;return bytes.toString();}
const spec=read('shared/drive/vehicleSpec.js');
const fn=spec.slice(spec.indexOf('export function mergeBoxes('),spec.indexOf('// 脱落碎片')).replace('export function','function');
const math=read('shared/core/math.js').replace(/export /g,'');
const rotations=read('shared/core/rotations.js').replace(/^import .*;\r?\n/gm,'').replace(/export /g,'');
const api=vm.runInNewContext(`(()=>{${math};${rotations};const CELL=.5,key=(x,y,z)=>[x,y,z].join(',');${fn};return {mergeBoxes,applyRot};})()`);
const cases=[];
function add(name,rows){const cells=new Map(rows.map(r=>[r.slice(0,3).join(','),r[3]]));cases.push({name,rows,expected:api.mergeBoxes(cells)});}
add('empty',[]);
for(const [name,m] of [['zero',0],['half',.5],['double',2],['belowHalf',.5-1e-12],['aboveDouble',2+1e-12]])add(name,[[0,0,0,1],[1,0,0,m]]);
add('allZero',[[0,0,0,0],[1,0,0,0],[0,1,0,0]]);
add('zeroSeed',[[0,0,0,0],[1,0,0,1],[2,0,0,0]]);
add('seedNotRolling',[[0,0,0,1],[1,0,0,2],[2,0,0,4]]);
add('heavyBodyLightDecoration',Array.from({length:16},(_,i)=>[0,0,i,i<4?5:.15]));
for(let rot=0;rot<24;rot++){
 const rows=[];
 for(let y=-2;y<=1;y++)for(let z=-3;z<=4;z++)for(let x=-3;x<=2;x++){
  if((x*x+y*y+z*z)%7===0)continue;
  const p=api.applyRot(rot,[x,y,z]);rows.push([...p,[0,.15,.5,1,2,5][((x+3)*13+(y+2)*7+(z+3))%6]]);
 }
 add('negative24rot-'+rot,rows);
}
let state=173;
function rand(){state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;}
for(let n=0;n<80;n++){
 const rows=[];for(let y=-2;y<3;y++)for(let z=-3;z<4;z++)for(let x=-3;x<4;x++)if(rand()<.7)rows.push([x,y,z,[0,.15,.5,1,2,5][Math.floor(rand()*6)]]);
 add('mixed-'+n,rows.reverse());
}
process.stdout.write(JSON.stringify({commit,inputs,cases}));
