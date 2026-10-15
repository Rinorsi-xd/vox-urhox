import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';

const baseline=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
for(let number=1;number<=4;number++){
  const relative='shared/story/level'+number+'.js';
  const source=path.join(baseline.snapshot,relative);
  const imported=await import(pathToFileURL(source).href);
  const original=imported['LEVEL'+number];
  const level=JSON.parse(JSON.stringify(original));
  if(number===2){
    level.setup={collectors:[[-188,-12,6]]};level.gradePolicy='truckHp';level.resultPolicy='truck';
  }else if(number===3){
    level.setup={};level.gradePolicy='shield';level.resultPolicy='shield';
  }else if(number===4){
    level.setup={sites:[{id:'A',pos:[-190,-12,0]},{id:'B',pos:[120,.35,117]},{id:'C',pos:[0,28,-22]}]};level.resultPolicy='sites';
  }
  original.steps.forEach((step,i)=>step.beats?.forEach((beat,j)=>{
    if(beat.when){
      const code=String(beat.when).replace(/\s/g,'');
      const translated={'(m)=>!m.alive()':'noEnemies','(m)=>m.hold.energy<0.97':'shieldDamaged'}[code];
      if(!translated)throw Error('Unknown frozen story condition '+code);
      level.steps[i].beats[j].when=translated;
    }
    if(beat.run){
      const code=String(beat.run).replace(/\s/g,'');
      if(code!=="(m)=>{m.dropPos=[0,6.2,-214];m.view.addIntel('coupon',m.dropPos);}")throw Error('Unknown frozen story action '+code);
      level.steps[i].beats[j].run='dropCoupon';
    }
  }));
  const file='assets/Story/Mission/Level'+number+'.json';
  const previous=JSON.parse(fs.readFileSync(file,'utf8'));
  previous.level=level;
  previous.source={branch:baseline.branch,commit:baseline.commit,scriptSha256:sha(fs.readFileSync(source))};
  fs.writeFileSync(file,JSON.stringify(previous));
  console.log(JSON.stringify({number,steps:level.steps.length,scriptSha256:previous.source.scriptSha256}));
}
