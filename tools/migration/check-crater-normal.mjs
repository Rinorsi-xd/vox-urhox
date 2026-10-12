// Compare derivative frames with the actual Three r186 shader expressions.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Vector3,ShaderChunk} from 'file:///D:/Rino_Project/Vox/three/vendor/three/build/three.module.js';
assert.ok(ShaderChunk.normalmap_pars_fragment.includes('max( dot( T, T ), dot( B, B ) )'));
const v=(x,y,z)=>new Vector3(x,y,z), cross=(a,b)=>a.clone().cross(b);
const mirror=a=>v(-a.x,a.y,a.z);
function frame(q0,q1,n,st0,st1){
  const a=cross(q1,n),b=cross(n,q0);
  return [a.clone().multiplyScalar(st0[0]).addScaledVector(b,st1[0]),a.multiplyScalar(st0[1]).addScaledVector(b,st1[1])];
}
let cases=0,maxError=0;
for(const face of [1,-1])for(const flipY of [1,-1])for(const uvMirror of [1,-1])for(let i=0;i<30;i++){
  const n=v(.2,.3,1).normalize(),q0=v(1+i/17,.2,0);
  q0.addScaledVector(n,-q0.dot(n));
  const q1=cross(n,q0).multiplyScalar(face*(.5+i/20));
  const st0=[.3*uvMirror,.08],st1=[-.12,.4];
  const map=v(.1+i/100,-.2,1).normalize();
  // Three flips N before deriving the frame, then flips T/B on back faces.
  const [t,b]=frame(q0,q1,n.clone().multiplyScalar(face),st0,st1);
  const scale=1/Math.sqrt(Math.max(t.lengthSq(),b.lengthSq()));
  const expected=mirror(t.multiplyScalar(scale*face*map.x).addScaledVector(b,scale*face*map.y).addScaledVector(n,face*map.z).normalize());
  const nn=mirror(n),a=mirror(q0),c=mirror(q1).multiplyScalar(flipY);
  const [nt,nb]=frame(a,c,nn,st0,st1.map(x=>x*flipY));
  const sign=a.dot(cross(c,nn))<0?-1:1;
  const k=sign/Math.sqrt(Math.max(nt.lengthSq(),nb.lengthSq()));
  const actual=nt.multiplyScalar(k*map.x).addScaledVector(nb,k*map.y).addScaledVector(nn,map.z).normalize().multiplyScalar(face);
  const error=expected.distanceTo(actual);maxError=Math.max(maxError,error);assert.ok(error<1e-12);cases++;
}
const report={cases,maxError,scope:'Three r186 derivative frame parity; front/back, reflected world X, screen Y reversal, mirrored UV, nonuniform derivative lengths'};
fs.writeFileSync(new URL('../../docs/migration/evidence/crater-normal-basis.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(report);
