const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));

function holdPlan(step,position,targets){
 if(step?.kind!=='hold')return null;
 const candidates=(Array.isArray(targets)?targets:[]).filter(t=>t.team==='red'&&Array.isArray(t.pos)&&flat(t.pos,step.pos)<step.drainR&&flat(t.pos,position)<=70);
 candidates.sort((a,b)=>flat(a.pos,position)-flat(b.pos,position));
 return {goal:step.pos,target:candidates[0]?.pos||null,park:flat(position,step.pos)<step.healR*.65};
}

function aimSolution(camera,target,tracking,now){
 const eye=[-camera.position[0],camera.position[1],camera.position[2]];
 let lead=[0,0,0];
 if(tracking.target&&now>tracking.at){
  const elapsed=(now-tracking.at)/1000;
  const velocity=[(target[0]-tracking.target[0])/elapsed,0,(target[2]-tracking.target[2])/elapsed];
  // A target switch or retry must never turn a position jump into a lead.
  if(elapsed<=.4&&Math.hypot(velocity[0],velocity[2])<=35)lead=velocity.map(v=>v*.10);
 }
 tracking.target=[...target];tracking.at=now;
 const dx=target[0]+lead[0]-eye[0],dz=target[2]+lead[2]-eye[2];
 const yaw=wrap(-Math.atan2(dx,dz)-camera.yaw*Math.PI/180);
 const pitch=-Math.atan2(target[1]+2-eye[1],Math.max(1,Math.hypot(dx,dz)))*180/Math.PI;
 return {dx:clamp(yaw/.0024,-300,300),dy:clamp((pitch-camera.pitch)/(180/Math.PI*.002),-200,200),lead,yawError:yaw,pitch};
}

module.exports={holdPlan,aimSolution};
