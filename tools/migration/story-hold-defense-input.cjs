const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const finite=p=>Array.isArray(p)&&p.length===3&&p.every(Number.isFinite);

function defensePlan(step,position,targets,memory,now,options={}){
 if(step?.kind!=='hold')return null;
 const exterior=options.nav?.nodes;
 const candidates=(Array.isArray(targets)?targets:[]).filter(t=>t.team==='red'&&finite(t.pos)&&(!exterior?flat(t.pos,step.pos)<step.drainR:true)&&flat(t.pos,position)<=(exterior?160:70));
 candidates.sort((a,b)=>flat(a.pos,step.pos)-flat(b.pos,step.pos));
 let selected;
 if(memory.target&&now-memory.at<1500){
  const nearest=candidates.slice().sort((a,b)=>flat(a.pos,memory.target)-flat(b.pos,memory.target))[0];
  if(nearest&&flat(nearest.pos,memory.target)<=4+35*(now-memory.at)/1000)selected=nearest;
 }
 selected??=candidates[0];
 if(exterior){
  const health=Number.isFinite(options.health)?options.health:1;
  if(health<.45)memory.repair=true;else if(health>.85)memory.repair=false;
  if(memory.repair)return {goal:step.pos,target:selected?.pos||null,park:flat(position,step.pos)<step.healR*.65,reason:'return-for-observed-damage',lineOfSight:'UNKNOWN',focusChanged:false};
  const nodes=Object.entries(exterior).filter(([,p])=>finite(p)&&flat(p,step.pos)>=step.drainR+15&&flat(p,step.pos)<=step.drainR+100);
  if(nodes.length){
   const score=p=>flat(p,position)*.18+(selected?Math.abs(flat(p,selected.pos)-35):0);
   nodes.sort((a,b)=>score(a[1])-score(b[1]));
   const retained=memory.patrol&&nodes.find(([id])=>id===memory.patrol);
   const node=retained&&now-memory.patrolAt<3000&&(!selected||flat(retained[1],selected.pos)>18)?retained:nodes[0];
   if(node[0]!==memory.patrol){memory.patrol=node[0];memory.patrolAt=now;}
   const changed=!!selected&&(!memory.target||flat(selected.pos,memory.target)>4+35*Math.max(0,now-(memory.at||now))/1000);
   memory.target=selected?[...selected.pos]:null;memory.at=now;
   return {goal:[...node[1]],goalNodeId:node[0],target:selected?.pos||null,targetId:selected?.unitId,park:flat(position,node[1])<5,reason:'intercept-on-authored-road-outside-drain-circle',lineOfSight:'UNKNOWN',targetParts:selected?.parts,focusChanged:changed};
  }
 }
 if(!selected){memory.target=null;return {goal:step.pos,target:null,park:flat(position,step.pos)<step.healR*.65,reason:'no-observed-draining-target',lineOfSight:'UNKNOWN'};}
 const switched=!memory.target||flat(selected.pos,memory.target)>4+35*Math.max(0,now-memory.at)/1000;
 if(switched){memory.focusAt=now;memory.parts=selected.parts;memory.lastDamageAt=now;}
 if(Number.isFinite(selected.parts)&&selected.parts<memory.parts)memory.lastDamageAt=now;
 memory.parts=selected.parts;memory.target=[...selected.pos];memory.at=now;
 const dx=selected.pos[0]-step.pos[0],dz=selected.pos[2]-step.pos[2],length=Math.max(1,Math.hypot(dx,dz));
 // Move within the authored repair circle; screen projection is not a LOS test.
 const radius=Math.min(step.healR*.72,length*.55),side=now-memory.lastDamageAt>3000?Math.min(6,step.healR*.2)*(Math.floor((now-memory.lastDamageAt)/3000)%2?1:-1):0;
 const scale=Math.min(1,step.healR*.85/Math.hypot(radius,side));
 const goal=[step.pos[0]+(dx/length*radius-dz/length*side)*scale,step.pos[1],step.pos[2]+(dz/length*radius+dx/length*side)*scale];
 return {goal,target:selected.pos,targetId:selected.unitId,park:flat(position,goal)<3,reason:side?'seek-new-firing-angle':'intercept-inside-repair-circle',lineOfSight:'UNKNOWN',targetParts:selected.parts,focusChanged:switched};
}

function alignedForFire(aim){return !!aim&&Math.abs(aim.yawError)<.045&&Math.abs(aim.dy)<18;}

module.exports={defensePlan,alignedForFire};
