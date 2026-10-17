const fs=require('node:fs');

function createStopController({file,maxHoldFailures=2,read=fs.readFileSync,exists=fs.existsSync}={}){
 let requested;
 return {
  request(reason='Operator requested stop'){requested??={kind:'operator',reason};},
  poll(state){
   if(requested)return requested;
   if(file&&exists(file)){requested={kind:'operator-file',reason:String(read(file,'utf8')).slice(0,500)||'Operator stop file'};return requested;}
   if(state?.story?.id==='s3'&&Number.isInteger(state.story.stats?.fails)&&state.story.stats.fails>=maxHoldFailures)
    return {kind:'driver-failure-budget',reason:'S3 public driver reached '+maxHoldFailures+' failed holds',observedFailures:state.story.stats.fails};
   return null;
  },
 };
}

async function returnThroughPublicInput({state,release,press,returnViaUi,now=Date.now}){
 const deadline=now()+30000;let timer;
 const remaining=()=>{const left=deadline-now();if(left<=0)throw Error('Public return exceeded 30-second total budget');return left;};
 try{return await Promise.race([(async()=>{
  await release();
  if(state.mode!=='trial')return {result:'NOT_IN_TRIAL',mode:state.mode};
  remaining();if(!state.story?.finished)await press('Escape');
  const returned=await returnViaUi(remaining());
  remaining();
  if(returned.mode!=='hangar'||returned.loadingFlow?.active||returned.performance?.arrayBytes!==0)
   throw Error('Public stop did not confirm returned hall and released terrain');
  return {result:'RETURNED',arrayBytes:returned.performance.arrayBytes};
 })(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Public return exceeded 30-second total budget')),30000);})]);}
 finally{clearTimeout(timer);}
}

module.exports={createStopController,returnThroughPublicInput};
