const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),dir=path.join(root,'docs/migration/evidence');
const prefix=process.argv[2]||'boss-wing-web-phone-landscape-935b3961-real-ending';
const manifest=process.argv[3]||'manifest-935b3961.json',base=process.argv[4]||'http://127.0.0.1:4279';
const log=fs.readFileSync(path.join(dir,prefix+'.log'),'utf8'),states=[];
for(const line of log.split(/\r?\n/)){
 const i=line.indexOf('OUTGAME_STATE ');if(i<0)continue;
 try{states.push({stamp:line.slice(0,i),state:JSON.parse(line.slice(i+14))});}catch{}
}
const active=states.filter(q=>q.state.story?.naturalEpilogueDetail?.active),observed=new Map(),lines=new Set(),panels=new Set();
for(const q of active){const ep=q.state.story.naturalEpilogueDetail;observed.set(ep.index,ep);if(ep.kind==='say'&&ep.voice?.text)lines.add(ep.voice.text);if(ep.kind==='panel')panels.add(ep.index);}
const after=states.slice(active.length?states.lastIndexOf(active.at(-1))+1:0);
const report={result:'FAIL',provenance:'Recovered from original immutable console log after Web Aborted(OOM) left Playwright failure screenshot unresolved. Test process was stopped; no original log edited. This is not a replay or complete passing route.',
 logSha256:crypto.createHash('sha256').update(log).digest('hex'),manifest,base,
 errors:log.split(/\r?\n/).filter(s=>/Aborted\(|ERROR:|stack traceback/.test(s)),
 naturalEpilogue:{observations:[...observed.values()],lines:[...lines],panelSteps:[...panels],stamp:[...observed.values()].some(q=>q.kind==='stamp'),
  observedAutomaticHangarReturn:after.some(q=>q.state.mode==='hangar'),voicePlayedMax:Math.max(0,...active.map(q=>q.state.story.naturalEpilogueDetail.voicePlayed)),
  evidenceBoundary:'Boss phases use explicit QA progression. Epilogue uses actual Mission.StartEpilogue after real mission finished; no input or clock edits during playback. Observed eight original lines, four panels and stamp do not close full five-mission natural play or this failed continuous-entry route.'},
 lastState:states.at(-1),stateCount:states.length,
 memoryTimeline:states.map(q=>({stamp:q.stamp,mode:q.state.mode,map:q.state.map||q.state.loadingFlow?.map,phase:q.state.loadingFlow?.phase,performance:q.state.performance})),
 failureBoundary:'Story5 -> natural epilogue -> hangar -> feather trial -> hangar -> second crater scene load aborts OOM. This recovery makes no claim about another build or independent PC route. Desktop touch emulation is not physical mobile performance evidence.'};
fs.writeFileSync(path.join(dir,prefix+'-oom-recovered.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({result:report.result,states:states.length,lines:lines.size,panels:panels.size,stamp:report.naturalEpilogue.stamp,errors:report.errors}));
