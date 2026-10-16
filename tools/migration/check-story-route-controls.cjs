// Exercise the actual natural-driver command helper without launching a browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'../..'),file=path.join(__dirname,'check-story-natural-web.cjs');
const source=fs.readFileSync(file,'utf8'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function load(text){
 const module={exports:{}};
 vm.runInNewContext(text,{require:createRequire(file),module,exports:module.exports,__filename:file,__dirname,process,console,Buffer,setTimeout,structuredClone},{filename:file});
 return module.exports;
}
const cases=[
 ['overspeed straight',{speed:16},['Space']],
 ['overspeed left',{speed:16,angle:.5},['Space','a']],
 ['overspeed right',{speed:16,angle:-.5},['Space','d']],
 ['reverse overspeed left input',{speed:-16,reversing:true,angle:.5},['Space','d']],
 ['reverse overspeed right input',{speed:-16,reversing:true,angle:-.5},['Space','a']],
 ['reverse below speed',{speed:-8,reversing:true,angle:.5},['s','d']],
 ['forward below speed',{speed:8,angle:-.5},['w','d']],
 ['equal speed stays throttle',{speed:15},['w']],
 ['just above speed brakes',{speed:15.00001},['Space']],
 ['negative equal speed stays throttle',{speed:-15},['w']],
 ['distance speed limit equal',{speed:10,goalDistance:25},['w']],
 ['distance speed limit above',{speed:10.00001,goalDistance:25},['Space']],
 ['enemy near straight',{enemy:true,distance:24.999,speed:0},['Space']],
 ['enemy near left',{enemy:true,distance:24.999,speed:0,angle:.5},['Space','a']],
 ['enemy near reverse right',{enemy:true,distance:24.999,reversing:true,angle:.5},['Space','d']],
 ['enemy exact distance',{enemy:true,distance:25,speed:12},['w']],
 ['enemy outside below speed',{enemy:true,distance:25.001,speed:11},['w']],
 ['enemy outside overspeed',{enemy:true,distance:25.001,speed:12.001,angle:-.5},['Space','d']],
 ['enemy near while following ramp',{enemy:true,distance:15,speed:0,routeFollowing:true},['w']],
 ['positive turn boundary',{speed:16,angle:.12},['Space']],
 ['negative turn boundary',{speed:16,angle:-.12},['Space']],
 ['positive turn above boundary',{speed:16,angle:.12001},['Space','a']],
 ['negative turn above boundary',{speed:16,angle:-.12001},['Space','d']],
 ['zero speed straight',{speed:0},['w']],
];
const priorPath='docs/migration/evidence/story-natural-s1-manifest-5b8cf21c-2026-10-16T01-18-07-151Z/result.json';
const priorBytes=fs.readFileSync(path.join(root,priorPath)),prior=JSON.parse(priorBytes);
const replay=prior.samples.filter(s=>s.at>=49521&&s.at<=50488).map(s=>({at:s.at,position:s.vehicle.position,
 input:{enemy:false,distance:Math.hypot(s.vehicle.position[0]-s.story.target[0],s.vehicle.position[2]-s.story.target[2]),speed:s.vehicle.speed,
 goalDistance:s.navigation.distance,reversing:s.navigation.reversing,angle:s.navigation.angle},observed:s.navigation.command,expected:['Space','a']}));
assert.equal(replay.length,4,'Four actual pre-fall command samples retained');
function verify(api){
 let checks=0;
 for(const [label,overrides,expected]of cases){
  const actual=api.navigationCommand({enemy:false,distance:100,speed:0,goalDistance:100,reversing:false,angle:0,...overrides});
  assert.deepEqual(Array.from(actual),expected,label);checks++;
 }
 for(const row of replay){assert.deepEqual(row.observed,['Space'],'Original missing-steering command reproduced');checks++;
  assert.deepEqual(Array.from(api.navigationCommand(row.input)),row.expected,'Actual pre-fall sample now retains steering');checks++;
 }
 return checks;
}
const checks=verify(load(source));
const mutations={
 'drop steering when braking':["return [braking?'Space':throttle,...(turning?[turning]:[])];","return braking?['Space']:[throttle,...(turning?[turning]:[])];"],
 'ignore reverse steering':['steer=reversing?-angle:angle','steer=angle'],
 'ignore reverse speed magnitude':['Math.abs(speed)>desired','speed>desired'],
 'brake at equal speed':['Math.abs(speed)>desired','Math.abs(speed)>=desired'],
 'brake at exact enemy distance':['distance<25','distance<=25'],
 'enemy proximity stops ramp navigation':['engaging=enemy&&!routeFollowing','engaging=enemy'],
 'steer at exact deadzone':['Math.abs(steer)>.12','Math.abs(steer)>=.12'],
 'ignore approach speed limit':['Math.min(15,Math.sqrt(goalDistance)*2)','15'],
};
for(const [label,[old,replacement]]of Object.entries(mutations)){
 assert(source.includes(old),'Mutation anchor '+label);
 assert.throws(()=>verify(load(source.replace(old,replacement))),'Reject '+label);
}
assert(source.includes('sample.navigation.command=navigationCommand({enemy,distance,speed:state.vehicle.speed||0,goalDistance:d,reversing,angle,routeFollowing:route.length>0});'),'Actual driver consumes the helper with road-following state');
assert.equal(sha(fs.readFileSync(file)),sha(source),'Tool stayed frozen during controls');
assert.equal(sha(fs.readFileSync(path.join(root,priorPath))),sha(priorBytes),'Prior OOM evidence unchanged');
const evidence={result:'PASS',checks:checks+4,cases:cases.length,rejectedMutations:Object.keys(mutations),replay,
 inputs:{'tools/migration/check-story-natural-web.cjs':sha(source),'tools/migration/check-story-route-controls.cjs':sha(fs.readFileSync(__filename))},
 priorRun:{path:priorPath,sha256:sha(priorBytes),result:prior.result},
 boundary:'CPU-only command selection and counterfactual commands over unchanged failed samples. No new vehicle trajectory, browser, GPU, collision/mission fix or OOM resolution. Original goals, acceptance, time limit and keyboard/mouse control remain unchanged.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/story-route-controls-offline.json'),JSON.stringify(evidence,null,2)+'\n');
console.log(JSON.stringify(evidence,null,2));
