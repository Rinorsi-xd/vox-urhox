const assert=require('node:assert/strict');
const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
function segment(p,a,b){
 const dx=b[0]-a[0],dz=b[2]-a[2],length=Math.hypot(dx,dz);
 const t=length?((p[0]-a[0])*dx+(p[2]-a[2])*dz)/(length*length):0;
 const q=a.map((v,i)=>v+(b[i]-v)*Math.max(0,Math.min(1,t)));
 return {t,cross:flat(p,q),length};
}
class RoadFollower{
 constructor(points){assert.ok(points.length);this.points=points;this.index=0;this.passed=[];}
 update(p,speed=0){
  const points=this.points;
  while(this.index<points.length){
   const point=points[this.index],width=point.width||16,radius=Math.min(6,width*.3);
   const incoming=this.index>0?segment(p,points[this.index-1].g,point.g):null;
   const outgoing=this.index+1<points.length?segment(p,point.g,points[this.index+1].g):null;
   const reached=flat(p,point.g)<=radius;
   // Accept a sampled overshoot only inside the marked road corridor.
   const passed=outgoing&&outgoing.t>=0&&outgoing.t<=1&&outgoing.cross<=width*.4&&(!incoming||incoming.t>=1);
   if(!reached&&!passed)break;
   this.passed.push({id:point.id,reason:reached?'radius':'segment',distance:flat(p,point.g)});this.index++;
  }
  if(this.index===points.length)return {done:true,index:this.index};
  const point=points[this.index],next=points[this.index+1],distance=flat(p,point.g);
  let target=point.g;
  if(next){
   const look=Math.min(8,(point.width||16)*.35,Math.max(3,speed*.7));
   const along=segment(p,point.g,next.g);
   if(distance<look&&along.length){const t=Math.min(.35,(look-distance)/along.length);target=point.g.map((v,i)=>v+(next.g[i]-v)*t);}
  }
  return {done:false,index:this.index,point,target,distance};
 }
}
function netCargo(gross,exit){
 const net={...gross};
 if(exit.needs){assert.ok(net[exit.needs]>=1,'Gross cargo contains actual extraction ticket');if(--net[exit.needs]===0)delete net[exit.needs];}
 return net;
}
function assertNetResult(result,gross,exit,items){
 const expected=netCargo(gross,exit);
 assert.equal(result.ok,true,'Natural extraction succeeded');
 assert.deepEqual(result.cargo,expected,'Actual result contains gross cargo minus exactly one extraction ticket');
 const value=Object.entries(expected).reduce((sum,[id,n])=>{assert.ok(items[id],'Known source cargo '+id);return sum+Math.max(1,Math.floor(items[id].price*.6))*n;},0);
 assert.equal(result.value,value,'Actual result values only net retained cargo');
 return {cargo:expected,value};
}
function assertSavedInventory(inventory){
 assert.ok(inventory?.saved?.data,'Read-only actual store:Read stash result is required');
 assert.ok(inventory.saved.generation>0,'Actual stash has a saved generation');
 for(const field of ['items','stats','credits','lastRun','lastStartedRun'])assert.deepEqual(inventory.saved.data[field],inventory[field],'Saved stash readback matches live '+field);
 return inventory.saved.generation;
}
function assertCountdown(samples,exit,strict){
 const observed=samples.filter(s=>s.id===exit.id&&Number.isFinite(s.left));
 if(strict)assert.ok(observed.length>=2,'Strict natural extraction requires actual original countdown samples');
 for(let i=0;i<observed.length;i++){
  assert.ok(observed[i].left<=exit.wait&&observed[i].left>=0,'Actual extraction countdown stays within original wait');
  if(i)assert.ok(observed[i].left<=observed[i-1].left,'Actual extraction countdown never restarts');
 }
 if(strict)assert.ok(observed.at(-1).left<observed[0].left,'Actual extraction countdown visibly decreases');
 return {status:observed.length?'OBSERVED':'OPEN',samples:observed.length,originalWait:exit.wait};
}
module.exports={flat,segment,RoadFollower,netCargo,assertNetResult,assertSavedInventory,assertCountdown};
