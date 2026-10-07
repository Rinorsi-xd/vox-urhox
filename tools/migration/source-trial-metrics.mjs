import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { TrackSim }=await import(pathToFileURL('D:/Rino_Project/Vox/shared/drive/trackSim.js'));
const drag={x0:-8,x1:8,start:0,finish:100};
const sim=Object.create(TrackSim.prototype);
Object.assign(sim,{layout:{drag},timing:{state:'idle',t0:0,last:null},events:[],time:0,stats:{recent:[]}});
const cases=[];
for(const [time,pos,speed,prevZ] of [
  [0,[0,1,-1],2,-2],[1,[0,1,0],4,-1],[2,[0,1,50],8,49],[3,[0,1,100],10,99],
  [4,[0,1,0],-3,-1],[5,[0,1,0],0,-1],[6,[10,1,0],5,-1],
  [7,[0,1,0],5,-1],[8,[10,1,50],8,49],[9,[0,1,0],5,-1],[10,[0,1,-2],-5,0],
  [11,[-9.9,1,0],5,-1],[12,[-9.9,1,100],15,99],[13,[-10,1,0],5,-1],
  [14,[0,1,1],8,-1],[17,[0,1,101],20,99]]) {
  sim.time=time;sim.updateTiming(pos,speed,prevZ);
  cases.push({time,pos,speed,prevZ,state:sim.timing.state,t0:sim.timing.t0,last:sim.timing.last,timer:sim.timer});
}
const damage=[];
for(const [time,amount] of [[0,20],[0,30],[1,90],[3,60],[3.001,0],[4,15],[7,0],[7.01,0]]){
  if(amount)sim.stats.recent.push([time,amount]);
  sim.stats.recent=sim.stats.recent.filter(r=>r[0]>=time-3);
  damage.push({time,amount,dps:sim.dps});
}
fs.writeFileSync(new URL('./source-trial-metrics.json',import.meta.url),JSON.stringify({drag,cases,damage},null,2));
console.log(`Original H5: ${cases.length} lane cases, ${damage.length} damage windows`);
