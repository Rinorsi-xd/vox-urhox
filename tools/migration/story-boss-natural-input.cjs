const attackStates=new Set(['fight','stomp','sweep','lanes','ult','recover','slamCrouch','slamAir','stuck','kneel','rise','barrage','transition']);
const point=p=>Array.isArray(p)&&p.length===3&&p.every(Number.isFinite);
const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
const onScreen=view=>view&&view.behind===false&&view.x>=0&&view.x<=1&&view.y>=0&&view.y<=1;
function bossPlan(state){
 const story=state.story,boss=story?.boss;if(!boss)return null;
 const base={goal:point(story.target)?story.target:null,point:null,targetKey:null,firing:false,aimHeight:0};
 if(boss.flow!=='fight'||boss.cinematic)return {...base,reason:'natural-cinematic-wait'};
 if(story.marker?.kind==='goal')return {...base,reason:'shelter-navigation'};
 if(!attackStates.has(boss.state))return {...base,reason:'boss-not-attackable'};
 if(typeof boss.braced!=='boolean'||!point(boss.cockpit))return {...base,reason:'missing-read-only-boss-observer'};
 const position=state.vehicle?.position;if(!point(position))return {...base,reason:'missing-player-position'};
 const live=(boss.nodes||[]).map((node,index)=>({node,index,view:boss.targetViews?.nodes?.[index]})).filter(n=>!n.node.broken&&n.node.hp>0&&point(n.node.pos));
 let selected;
 if(!boss.kneel&&!boss.braced&&live.length){
  live.sort((a,b)=>Number(onScreen(b.view))-Number(onScreen(a.view))||flat(a.node.pos,position)-flat(b.node.pos,position)||a.index-b.index);
  const chosen=live[0];selected={point:chosen.node.pos,targetKey:'node:'+chosen.index,view:chosen.view,reason:'live-energy-node',stopRange:30};
 }else selected={point:boss.cockpit,targetKey:'cockpit',view:boss.targetViews?.cockpit,reason:boss.kneel?'kneeling-cockpit':boss.braced?'braced-cockpit':'exposed-cockpit',stopRange:40};
 // This is an exact observed weak point. Legacy aimSolution adds two metres;
 // its input adapter below removes precisely that offset, without editing state.
 return {...base,...selected,legacyAimTarget:[selected.point[0],selected.point[1]-2,selected.point[2]],firing:true};
}
module.exports={bossPlan};
