const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
const names=['shared/controls/touchControls.js','shared/controls/cameraRig.js','shared/core/math.js','three/src/build/liveryStudio.js'];
const files={},hashes={};
for(const name of names){
 const bytes=fs.readFileSync(path.join(baseline.snapshot,name));
 hashes[name]=crypto.createHash('sha256').update(bytes).digest('hex');
 if(hashes[name]!==baseline.files[name].sha256)throw new Error('Frozen source drift '+name);
 files[name]=bytes.toString('utf8');
}
async function main(){
 const context=vm.createContext({URL,innerWidth:1920,innerHeight:1080,performance:{now:()=>0}});
 const math=new vm.SourceTextModule(files[names[2]],{context});await math.link(()=>{throw new Error('Unexpected math dependency')});await math.evaluate();
 const camera=new vm.SourceTextModule(files[names[1]],{context});await camera.link(()=>math);await camera.evaluate();
 const mobile=new vm.SyntheticModule(['mobileEditHtml','MobileEdit'],function(){this.setExport('mobileEditHtml',()=> '');this.setExport('MobileEdit',class{});},{context});
 const touch=new vm.SourceTextModule(files[names[0]],{context});await touch.link(()=>mobile);await touch.evaluate();
 const downText=files[names[3]].slice(files[names[3]].indexOf('\t_down( e ) {'),files[names[3]].indexOf('\n\t_startMove( e, i ) {'));
 const decalDown=vm.runInContext('({' + downText + '})._down',context);
 const {CameraRig}=camera.namespace,{TouchControls}=touch.namespace,{Vector3}=math.namespace;
 const rows=[];
 for(const [width,height] of [[1920,1080],[1333.333333,600],[840,378]])for(const sensitivity of [.6,1,2.2])for(const distance of [2.5,20,60]){
  context.innerWidth=width;context.innerHeight=height;
  const input={touchActive:true,mdx:0,mdy:0,down:()=>false,consumeMouse(){const v=[this.mdx,this.mdy];this.mdx=this.mdy=0;return v;}};
  const rig=new CameraRig(input,{onPose(){}});rig.maxDist=60;rig.panMaxY=20;rig.roomLimit={x:1000,z0:-1000,z1:1000,y0:-1000,y1:1000};rig.setOrbit([0,1.1,0],distance,.7,1.24);rig.autoSpin=false;rig.update(0);
  const basis={r:[rig.r.x,rig.r.y,rig.r.z],u:[rig.u.x,rig.u.y,rig.u.z]};
  const canvas={closest:()=>null,setPointerCapture(){},hasPointerCapture:()=>true,releasePointerCapture(){},classList:{add(){},remove(){}}};input.dom=canvas;
  const studio={active:true,editor:{input},pick:null,sel:-1,_decalAt:()=>-1,select(i){this.sel=i;}};
  const tc=Object.create(TouchControls.prototype);Object.assign(tc,{input,rig,editor:{pointerHook:e=>decalDown.call(studio,e)},mode:'home',prefs:{sens:sensitivity},pointers:new Map(),root:{contains:()=>false},blocked:()=>false,setEnabled(){},_fullscreen(){},update(){}});
  const actions=[['down',1,400,200],['move',1,420,210],['frame'],['down',2,700,200],['move',2,800,220],['move',1,390,210],['frame'],['up',2,800,220],['move',1,400,205],['frame'],['up',1,400,205],['frame'],['move',99,100,100],['frame'],['down',3,500,250],['down',4,506,250],['move',4,508,250],['frame'],['move',4,509,250],['frame'],['move',4,900,350],['frame'],['up',3,500,250],['up',4,900,350],['frame']];
  const steps=[];
  for(const action of actions){
   const [kind,id,x,y]=action,e={pointerType:'touch',pointerId:id,button:0,clientX:x,clientY:y,target:canvas,preventDefault(){},stopImmediatePropagation(){}};
   if(kind==='down')tc.pointerDown(e);else if(kind==='move')tc.pointerMove(e);else if(kind==='up')tc.pointerEnd(e);else rig.update(0);
   const o=rig.orbit;steps.push({action,dist:o.dist,yaw:180-o.theta*180/Math.PI,pitch:90-o.phi*180/Math.PI,target:[-o.target.x,o.target.y,o.target.z]});
  }
  rows.push({width,height,sensitivity,distance,basis,steps});
 }
 // Execute the actual livery hook to prove only unclaimed background reaches home gestures.
 const priority=[];
 for(const kind of ['background','decal','place','miss','space']){
  let selected=-1,started=0,placed=0;
  const s={active:true,editor:{input:{down:()=>kind==='space'}},pick:kind==='place'||kind==='miss'?'sticker':null,sel:-1,
   _decalAt:()=>kind==='decal'?2:-1,_surface:()=>kind==='place'?{}:null,
   select(i){selected=i;this.sel=i;},_startMove(){started++;},place(){placed++;this.sel=4;}};
  const claimed=decalDown.call(s,{button:0,clientX:400,clientY:200});
  priority.push({kind,claimed,selected,started,placed});
 }
 const out=path.join(root,'.tmp/source-livery-touch-fixtures.json');
 fs.writeFileSync(out,JSON.stringify({sourceCommit:baseline.commit,hashes,rows,priority,boundary:'Actual frozen TouchControls home pointer handlers and CameraRig with actual shared math; exact LiveryStudio._down extracted unchanged. DOM/capture boundaries are doubles. No GPU or rendering.'},null,2)+'\n');
 console.log(JSON.stringify({result:'PASS',cases:rows.length,steps:rows.reduce((n,r)=>n+r.steps.length,0),priority:priority.length,out}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
