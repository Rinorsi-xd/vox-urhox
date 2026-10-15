const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {createHash}=require('node:crypto'),{pathToFileURL}=require('node:url');
const {sourceRaidRoute}=require('./check-salvage-natural-web.cjs');
async function run(){
 const baseline=require('../../docs/migration/outgame-baseline.json'),root=path.resolve(__dirname,'../..'),source=path.resolve(root,baseline.snapshot);
 const names=['shared/build/blueprint.js','shared/build/prefab.js','shared/drive/vehicleSpec.js'],provenance={};
 for(const name of names){const sha=createHash('sha256').update(fs.readFileSync(path.join(source,name))).digest('hex');assert.equal(sha,baseline.files[name].sha256,'Frozen source hash '+name);provenance[name]=sha;}
 const [{Blueprint},prefabs,{buildVehicleSpec}]=await Promise.all(names.map(name=>import(pathToFileURL(path.join(source,name)))));
 const bp=new Blueprint();prefabs.buildScorpion(bp);const spec=buildVehicleSpec(bp);assert.ok(spec.ok);
 const size=spec.bounds.max.map((n,i)=>n-spec.bounds.min[i]),gp=require('../../assets/Salvage/Gameplay.json'),routes=[];
 for(const spawn of gp.spawns){
  const selected=sourceRaidRoute([-spawn.x,spawn.y+2,spawn.z]),road=selected.road;let maxSlope=0;
  for(const route of [selected.approachRoad,road].filter(Boolean)){
   for(const point of route.points)assert.deepEqual(point.g,gp.nav.nodes[point.id],'Actual original node '+point.id);
   for(let i=1;i<route.points.length;i++){const a=route.points[i-1],b=route.points[i];assert.ok(gp.nav.edges.some(e=>e[0]===a.id&&e[1]===b.id||e[0]===b.id&&e[1]===a.id),'Actual original edge');if(route===road)maxSlope=Math.max(maxSlope,Math.atan2(Math.abs(a.g[1]-b.g[1]),Math.hypot(a.g[0]-b.g[0],a.g[2]-b.g[2]))*180/Math.PI);}
  }
  assert.ok(!road.steepFallback&&maxSlope<=35,'Source route avoids original cliff-height edges');
  const minWidth=Math.min(...road.points.map(p=>p.width));
  routes.push({spawn:spawn.id,crate:selected.crate.id,exit:selected.exit.id,roadDistance:road.distance,roadPoints:road.points.length,maxSlope,minWidth,originalVehicleFitsMarkedWidth:size[0]<=minWidth,exposedPoints:selected.exposed,approachDistance:selected.approach,approachRoad:Boolean(selected.approachRoad),points:road.points});
 }
 const report={result:'PASS',sourceCommit:baseline.commit,provenance,vehicle:{id:'scorpion',parts:bp.toJSON().parts.length,size,mass:spec.motion.mass,topSpeed:spec.motion.topSpeed,legs:spec.legs.length,weapons:spec.weapons.length},routes,boundary:'Offline actual frozen H5 vehicle specification and original navigation topology only. Marked road width is not measured obstacle clearance; actual terrain, leg support, enemy damage and natural extraction remain unverified.'};
 const output=path.join(root,'docs/migration/evidence/salvage-route-offline.json');fs.writeFileSync(output,JSON.stringify(report,null,2));
 console.log(JSON.stringify({result:report.result,sourceCommit:report.sourceCommit,vehicle:report.vehicle,routes:routes.map(({points,...r})=>r),output}));
}
run().catch(error=>{console.error(error);process.exitCode=1;});
