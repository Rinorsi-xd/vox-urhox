const fs=require('node:fs'),path=require('node:path');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const out=path.resolve(root,process.argv[2]||JSON.parse(fs.readFileSync(path.join(root,'.tmp/scatter-culling-request.json'),'utf8')).out);
const parse=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/\0+$/,''));
async function pixels(file){return sharp(path.join(out,file)).ensureAlpha().raw().toBuffer({resolveWithObject:true});}
async function compare(a,b){
 const first=await pixels(a),next=await pixels(b);
 if(first.info.width!==next.info.width||first.info.height!==next.info.height)throw Error('Screenshot dimensions changed');
 let changed=0,darker=0,brighter=0,max=0,total=0;const colors=new Set();
 for(let i=0;i<first.data.length;i+=4){
  colors.add(first.data.readUInt32LE(i));let diff=0,light=0;
  for(let c=0;c<3;c++){const v=next.data[i+c]-first.data[i+c];diff=Math.max(diff,Math.abs(v));max=Math.max(max,Math.abs(v));total+=Math.abs(v);light+=v;}
  if(diff>2)changed++;if(light<-30)darker++;if(light>30)brighter++;
 }
 const count=first.data.length/4;
 return{pixels:count,changedAbove2:changed,changedFraction:changed/count,darkerAbove10:darker,brighterAbove10:brighter,
  maxChannelError:max,meanChannelError:total/(count*3),referenceColors:colors.size,withinTolerance:changed/count<=.001&&colors.size>32};
}
async function main(){
 const native=parse(path.join(out,'native.json'));
 if(native.result!=='MEASURED'||!native.completed)throw Error('Native experiment did not finish');
 const groups=new Map();for(const item of native.cases){const key=item.name+'/'+item.range;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(item);}
 const comparisons=[];
 for(const [key,items]of groups){
  const original=items.find(i=>i.mode==='original'&&!i.repeatBaseline),repeat=items.find(i=>i.repeatBaseline);
  if(!original||!repeat)throw Error('Missing baseline pair '+key);
  const drift=await compare(original.image,repeat.image);
  for(const mode of ['32','64']){
   const candidate=items.find(i=>i.mode===mode);if(!candidate)throw Error('Missing candidate '+key+'/'+mode);
   const delta=await compare(original.image,candidate.image);
   comparisons.push({view:key,mode,range:original.range,baselineDrift:drift,pixels:delta,
    visualResult:!drift.withinTolerance?'UNDETERMINED_BASELINE_DRIFT':delta.withinTolerance?'WITHIN_TOLERANCE':'DIFFERENT_REQUIRES_REJECTION_OR_REVIEW',
    original:{wallMs:original.wallMs,batches:original.batches,triangles:original.triangles},
    candidate:{wallMs:candidate.wallMs,batches:candidate.batches,triangles:candidate.triangles},
    medianChanges:{wallMs:candidate.wallMs.median-original.wallMs.median,batches:candidate.batches.median-original.batches.median,
      triangles:candidate.triangles.median-original.triangles.median},
    originalImage:original.image,candidateImage:candidate.image});
  }
 }
 const distanceChecks=[];
 for(const item of comparisons.filter(i=>i.range==='limited'&&i.view.startsWith('distance-'))){
  const unlimited=comparisons.find(i=>i.mode===item.mode&&i.view===item.view.replace('/limited','/unlimited-diagnostic'));
  distanceChecks.push({view:item.view,mode:item.mode,limited:item.visualResult,unlimited:unlimited?.visualResult,
   rangeBehaviorChanged:item.baselineDrift.changedAbove2===0&&item.pixels.changedAbove2>0&&unlimited?.pixels.changedAbove2===0,
   interpretation:item.baselineDrift.changedAbove2===0&&item.pixels.changedAbove2>0&&unlimited?.pixels.changedAbove2===0
    ?'Range/group-distance behavior changed; candidate cannot qualify from lower triangle counts.'
    :'Inspect paired screenshots and native group distances; counters alone do not establish per-instance distance semantics.'});
 }
 const result={result:'MEASURED_REQUIRES_VISUAL_REVIEW',scope:native.scope,partitions:native.partitions,configuration:native.configuration,
  candidateEligibility:Object.fromEntries(['32','64'].map(mode=>[mode,distanceChecks.some(i=>i.mode===mode&&i.rangeBehaviorChanged)?'NOT_QUALIFIED_RANGE_CHANGE':comparisons.filter(i=>i.mode===mode&&i.range==='limited').every(i=>i.visualResult==='WITHIN_TOLERANCE')?'PIXEL_CHECKS_ONLY_PASS_PENDING_REVIEW':'NOT_QUALIFIED'])),
  policy:'All original instances and authored properties retained. Unlimited-distance cases are diagnostic only and excluded from optimization eligibility. Setup, switch, screenshot and validation costs excluded from steady frames. Native renderer counters and wall intervals are not GPU timestamp queries or phone/Web acceptance.',
  comparisons,distanceChecks,provenance:native.provenance};
 fs.writeFileSync(path.join(out,'analysis.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({out,result:result.result,candidateEligibility:result.candidateEligibility,comparisons:comparisons.length}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
