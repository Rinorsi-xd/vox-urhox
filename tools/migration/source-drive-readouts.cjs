const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const source=fs.readFileSync(path.join(baseline.snapshot,'shared/ui/driveHud.js'),'utf8');
const start=source.indexOf('\t_updateSummary( tel ) {'),end=source.indexOf('\n\t// 准星两侧',start);
if(start<0||end<0)throw Error('Frozen H5 summary missing');
const method=source.slice(start,end),body=method.slice(method.indexOf('{')+1,method.lastIndexOf('}'));
const summary=vm.runInNewContext('(function(tel){'+body+'})');
const cases=[];
for(const liftRatio of [0,.7,1.5])for(const legs of ['none','short','wall','mech'])for(const hover of [null,0,1.8])for(const active of [false,true]){
 const tel={speed:active?-12:0,totalSpeed:active?16:0,contact:active?0:4,liftRatio,liftBalanceError:active?.2:0,
  flightHold:liftRatio>1&&active,altitude:21.4,altitudeTarget:24.6,hoverCount:hover===null?0:2,hovers:active?0:2,hoverHeight:active?null:hover,
  legCount:legs==='none'?0:legs==='short'?2:4,mechLegs:legs==='mech',legGrip:!active,legContacts:active?0:4,
  legWallPending:legs==='wall'&&!active,legClimbing:legs==='wall'&&active,legJumpReady:!active,legCooldown:active?.4:0,
  mechJetFuel:legs==='mech'?.37:null,mechBoostFuel:legs==='mech'?.62:1,mechBoost:legs==='mech'&&active,handbrake:active,boosting:active};
 const output={alert:{textContent:''},state:{textContent:''}};summary.call(output,tel);
 cases.push({tel,alert:output.alert.textContent,state:output.state.textContent});
}
fs.writeFileSync(path.join(root,'tools/migration/source-drive-readouts.json'),JSON.stringify({commit:baseline.commit,cases},null,2));
console.log('Frozen production summary executed: '+cases.length+' telemetry combinations');
