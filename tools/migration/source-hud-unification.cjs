const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const files=['shared/ui/reticle.js','shared/css/new-ui-reticle.css','three/src/drive/testDrive.js','shared/ui/homeScale.js'];
const texts=files.map(f=>fs.readFileSync(path.join(baseline.snapshot,f),'utf8'));
const [reticle,css,drive]=texts;
let compact=false;
const scales=vm.runInNewContext(texts[3].replaceAll('export ','')+';({reticleScale,homeViewport})',{
 document:{documentElement:{hasAttribute:()=>compact}}
});
const scaleCases=[];
for(const on of [false,true])for(const [w,h]of[[1920,1080],[2400,1080],[840,378],[844,390],[667,375],[1024,768]]){
 compact=on;scaleCases.push({w,h,compact:on,k:scales.reticleScale(w,h)});
}
function method(src,name,next){
 const start=src.indexOf('\t'+name+'('),end=src.indexOf(next,start);
 if(start<0||end<0)throw Error('Frozen source method missing '+name);
 return vm.runInNewContext('({'+src.slice(start,end).trim().replaceAll('import.meta.url',JSON.stringify('file:///frozen/shared/ui/reticle.js'))+'})',{
  DEG:Math.PI/180,f1:v=>v.toFixed(1),performance:{now:()=>100},URL
 })[name];
}
const compass=method(reticle,'_compass','\n\t// 掉血残影');
const waypoint=method(drive,'_waypoint','\n\t// 世界里一点相对镜头');
const chips=method(reticle,'_chips','\n\t// 两边俯仰刻度梯');
const zoomMatch=reticle.match(/export const SCOPE_ZOOM = ([^;]+);/);
if(!zoomMatch)throw Error('Frozen SCOPE_ZOOM unavailable');
const zoom=vm.runInNewContext('('+zoomMatch[1]+')');
const scopeStart=reticle.indexOf('function scopeSvg('),scopeEnd=reticle.indexOf('\nconst CSS',scopeStart);
const scope=vm.runInNewContext('('+reticle.slice(scopeStart,scopeEnd).trim()+')',{SCOPE_ZOOM:zoom});
if(!css.includes('body #driveHud .dh-cross-hint { display: none !important; }')||!css.includes('[data-seek] text.zl, [data-enmsg]'))throw Error('Final source HUD hiding contract changed');
const cases=[];
for(const [w,h]of[[1920,1080],[2400,1080],[1200,540]])for(const head of[0,90,359])for(const target of[[10,4,215],[-190,4,-185],[210,4,-185],[10,9,215],[10,-1,215],[210,8,15]]){
 const k=Math.min(w/1920,h/1080),host={innerHTML:''},com=[10,4,15];
 const wp=waypoint.call({modeController:{waypoint:{pos:target,label:'任务 <&',enemy:target[0]<0}}},com);
 compass.call({k,cx:w/2,q:()=>host},-head*Math.PI/180,wp);
 const svg=host.innerHTML;
 const diamond=svg.match(/filter:drop-shadow[^>]+d="M([\d.-]+) ([\d.-]+)l([\d.-]+) ([\d.-]+)/);
 const label=svg.match(/<text x="([\d.-]+)" y="([\d.-]+)" class="lbl mid" style="fill:(#[\da-f]+);stroke:none;font-size:[^"]+">([^<]*)<\/text>/);
 const height=svg.match(/<text x="([\d.-]+)" y="([\d.-]+)" class="n"[^>]*>(\d+)<\/text>/);
 if(!diamond||!label)throw Error('Actual source compass SVG parse failed');
 cases.push({w,h,head,com,target,wp,expected:{x:+diamond[1],y:+diamond[2]+ +diamond[4],r:+diamond[3],labelY:+label[2],label:label[4],color:label[3],height:height?+height[3]:null,edge:/<path style="fill:#[^";]+;stroke:none" d="M[^"v]+v[^"Z]+Z"/.test(svg)}});
}
const slotCases=[];
for(const [w,h]of[[1920,1080],[2400,1080],[1200,540]])for(let selected=0;selected<4;selected++){
 const k=Math.min(w/1920,h/1080),host={innerHTML:'',querySelector:()=>null};
 const groups=['mg','sniper','laser','missile'].map((kind,i)=>({kind,name:kind,count:1,sel:i===selected,output:1}));
 chips.call({k,wX:w/2+304*k,wY:h/2+84*k,q:()=>host},groups);
 const boxes=[...host.innerHTML.matchAll(/<polygon class="chip" points="([^"]+)"/g)].map(m=>{
  const pts=m[1].split(' ').map(p=>p.split(',').map(Number)),xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]);
  return {x:Math.min(...xs),y:Math.min(...ys),w:Math.max(...xs)-Math.min(...xs),h:Math.max(...ys)-Math.min(...ys)};
 });
 if(boxes.length!==4)throw Error('Actual source weapon slot SVG parse failed');
 slotCases.push({w,h,selected:selected+1,boxes});
}
const scopes=Object.fromEntries(Object.keys(zoom).map(kind=>[kind,scope(kind,1920,1080)]));
const scopeDots=[...scopes.sniper.matchAll(/<circle cx="([^"]+)" cy="([^"]+)" r="([^"]+)"/g)].map(m=>({x:+m[1],y:+m[2],r:+m[3]}));
const output={commit:baseline.commit,inputs:files.map((f,i)=>({file:f,sha256:crypto.createHash('sha256').update(texts[i]).digest('hex')})),zoom,scopes,scopeDots,cases,slotCases,scaleCases};
fs.writeFileSync(path.join(root,'tools/migration/source-hud-unification.json'),JSON.stringify(output,null,2));
console.log(JSON.stringify({result:'PASS',commit:baseline.commit,waypoints:cases.length,slots:slotCases.length,scopes:Object.keys(scopes).length,scales:scaleCases.length,inputs:output.inputs}));
