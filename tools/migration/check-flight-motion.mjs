import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {gunzipSync} from 'node:zlib';

const dir=process.argv[2];
assert(dir,'Usage: node check-flight-motion.mjs <evidence-directory>');
function load(name){
  const file=path.join(dir,name+'.json');
  return JSON.parse(fs.existsSync(file)?fs.readFileSync(file):gunzipSync(fs.readFileSync(file+'.gz')));
}
const before=load('native-before'),after=load('native-after'),source=load('source-motion');
assert.equal(before.result,'PASS');assert.equal(after.result,'PASS');
const keys=['x','y','z','w'];
function angle(a,b){
  const dot=keys.reduce((n,k)=>n+a[k]*b[k],0);
  const length=v=>Math.sqrt(keys.reduce((n,k)=>n+v[k]*v[k],0));
  return 2*Math.acos(Math.min(1,Math.abs(dot)/(length(a)*length(b))))*180/Math.PI;
}
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
const cases=[];
for(const id of ['feather','hawk']){
  const ref=source.rows.find(x=>x.id===id),old=before.rows.find(x=>x.id===id),now=after.rows.find(x=>x.id===id);
  assert(ref&&old&&now,'Missing aircraft '+id);assert.equal(ref.segments.length,8);
  for(const segment of ref.segments){
    const b=old.segments.find(x=>x.name===segment.name),a=now.segments.find(x=>x.name===segment.name);
    assert(b&&a,'Missing segment '+segment.name);
    assert.equal(segment.samples.length,120);assert.equal(b.samples.length,120);assert.equal(a.samples.length,120);
    const errors=n=>segment.samples.map((x,i)=>{
      assert.equal(n.samples[i].step,x.step);
      const err={angle:angle(x.state.q,n.samples[i].state.q),position:distance(x.state.p,n.samples[i].state.p)};
      assert(Number.isFinite(err.angle)&&Number.isFinite(err.position));return err;
    });
    const eb=errors(b),ea=errors(a),avg=(v,k)=>v.reduce((n,x)=>n+x[k],0)/v.length;
    const row={id,name:segment.name,attitudeMeanBefore:avg(eb,'angle'),attitudeMeanAfter:avg(ea,'angle'),
      attitudeEndBefore:eb.at(-1).angle,attitudeEndAfter:ea.at(-1).angle,
      positionMeanBefore:avg(eb,'position'),positionMeanAfter:avg(ea,'position')};
    assert(row.attitudeMeanAfter<row.attitudeMeanBefore,'Attitude did not improve: '+id+'/'+segment.name);
    assert(row.positionMeanAfter<row.positionMeanBefore,'Position did not improve: '+id+'/'+segment.name);
    cases.push(row);
  }
}
const car=before.rows.find(x=>x.id==='raceCar');assert(car,'Missing non-wing control');
assert.deepEqual(after.rows.find(x=>x.id==='raceCar'),car,'Non-wing behavior changed');
const avg=k=>cases.reduce((n,x)=>n+x[k],0)/cases.length;
console.log(JSON.stringify({result:'PASS',cases,nonWingUnchanged:true,
  meanAttitudeBefore:avg('attitudeMeanBefore'),meanAttitudeAfter:avg('attitudeMeanAfter'),
  meanPositionBefore:avg('positionMeanBefore'),meanPositionAfter:avg('positionMeanAfter'),
  boundary:'16 paired cases x120 real physics steps in empty worlds. No map contacts, rendering, subjective feel or mobile performance acceptance.'},null,2));
