import fs from 'node:fs';
const root='.tmp/g1-ground-damage-20261016/';
const read=p=>JSON.parse(fs.readFileSync(p));
const dist=(a,b)=>Math.hypot(...['x','y','z'].map(k=>a[k]-b[k]));
const angle=(a,b)=>{const dot=['x','y','z','w'].reduce((s,k)=>s+a[k]*b[k],0);const norm=q=>Math.hypot(q.x,q.y,q.z,q.w);return 2*Math.acos(Math.min(1,Math.abs(dot)/norm(a)/norm(b)))*180/Math.PI;};
const error=(n,s)=>({position:dist(n.p,s.p),linearVelocity:dist(n.lv,s.lv),angularVelocity:dist(n.av,s.av),attitudeDegrees:angle(n.q,s.q)});
const avg=(xs,k)=>xs.reduce((a,x)=>a+x[k],0)/xs.length;
const singleBefore=read(root+'native-climb-air-before.json'),singleAfter=read(root+'native-climb-air-after.json'),singleSource=read(root+'source-climb-air-result.json');
const single=singleSource.rows.map((s,i)=>({id:s.id,checkpoint:s.checkpoint,mode:s.mode,before:error(singleBefore.rows[i].afterPhysics,s.afterPhysics),after:error(singleAfter.rows[i].afterPhysics,s.afterPhysics),source:s,actualBefore:singleBefore.rows[i],actualAfter:singleAfter.rows[i]}));
const oldMotion=read('.tmp/flight-parity-20261016/after-snapshot/native-motion-result.json'),newMotion=read(root+'native-snapshot/native-motion-result.json'),sourceMotion=read('.tmp/flight-parity-20261016/source-motion-result.json');
const motion=[];
for(const s of sourceMotion.rows){for(const segment of s.segments){const before=oldMotion.rows.find(r=>r.id===s.id).segments.find(r=>r.name===segment.name),after=newMotion.rows.find(r=>r.id===s.id).segments.find(r=>r.name===segment.name);const eb=segment.samples.map((v,i)=>error(before.samples[i].state,v.state)),ea=segment.samples.map((v,i)=>error(after.samples[i].state,v.state));motion.push({id:s.id,name:segment.name,meanBefore:Object.fromEntries(Object.keys(eb[0]).map(k=>[k,avg(eb,k)])),meanAfter:Object.fromEntries(Object.keys(ea[0]).map(k=>[k,avg(ea,k)])),endBefore:eb.at(-1),endAfter:ea.at(-1)});}}
const oldGround=read(root+'native-ground-before-damping.json'),newGround=read(root+'native-ground-after-damping.json'),sourceGround=read(root+'source-ground-result.json');
const ground=sourceGround.rows.map((s,i)=>{const eb=s.samples.map((v,j)=>error(oldGround.rows[i].samples[j].state,v.state)),ea=s.samples.map((v,j)=>error(newGround.rows[i].samples[j].state,v.state));return{id:s.id,name:s.name,meanBefore:Object.fromEntries(Object.keys(eb[0]).map(k=>[k,avg(eb,k)])),meanAfter:Object.fromEntries(Object.keys(ea[0]).map(k=>[k,avg(ea,k)])),endBefore:eb.at(-1),endAfter:ea.at(-1)};});
const out={single,motion,ground};fs.writeFileSync(root+'climb-damping-comparison.json',JSON.stringify(out,null,2));
for(const mode of ['free','wing','full','freeZero','wingZero','fullZero']){const xs=single.filter(x=>x.mode===mode);console.log('SINGLE',mode,'meanAv',avg(xs.map(x=>x.before),'angularVelocity'),avg(xs.map(x=>x.after),'angularVelocity'),'maxAfter',Math.max(...xs.map(x=>x.after.angularVelocity)));}
for(const r of motion)console.log('MOTION',r.id,r.name,'mean angle',r.meanBefore.attitudeDegrees,r.meanAfter.attitudeDegrees,'mean p',r.meanBefore.position,r.meanAfter.position);
for(const r of ground)console.log('GROUND',r.id,r.name,'end p',r.endBefore.position,r.endAfter.position,'end angle',r.endBefore.attitudeDegrees,r.endAfter.attitudeDegrees);
