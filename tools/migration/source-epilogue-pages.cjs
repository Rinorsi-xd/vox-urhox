const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const name='three/src/battle/storyEpilogue.js',bytes=fs.readFileSync(path.join(baseline.snapshot,name)),sha=crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha,baseline.files[name].sha256,'Frozen original source identity');
const source=bytes.toString('utf8'),animations=[],elements=[],timers=new Map();let wall=0,serial=0;
class Element{
 constructor(tag){this.tag=tag;this.className='';this.style={};this.children=[];this.removed=false;this.classes=new Set();this.classList={add:k=>this.classes.add(k),remove:k=>this.classes.delete(k)};elements.push(this);}
 appendChild(e){this.children.push(e);e.parent=this;return e;}
 append(...all){for(const e of all)this.appendChild(e);}
 insertBefore(e){return this.appendChild(e);}
 remove(){this.removed=true;this.parent?.children.splice(this.parent.children.indexOf(this),1);}
 addEventListener(){}
 querySelector(selector){if(selector==='.chr')return null;const e=new Element('selector');e.className=selector;return e;}
 animate(frames,options){animations.push({at:wall,className:this.className,frames:structuredClone(frames),options:structuredClone(options)});}
}
const body=new Element('body'),card={root:new Element('card'),hide(){},say(){},update(){},skipLine(){},queue:[]};
const context=vm.createContext({URL,document:{body,createElement:tag=>new Element(tag)},performance:{now:()=>wall},
 setTimeout(fn,ms){const id=++serial;timers.set(id,{at:wall+ms,fn});return id;},clearTimeout:id=>timers.delete(id),
 requestAnimationFrame(){return ++serial;},cancelAnimationFrame(){},addEventListener(){},removeEventListener(){},
 radio(){},comms:{use:()=>card,release(){}},CHAIRMAN:'chairman',HUHU_FACES:{smug:'huhu',angry:'huhuAngry'}});
// Only module linkage is adapted; original playEpilogue executes intact.
vm.runInContext(source.replace(/^import .*;\r?$/gm,'').replaceAll('import.meta.url',JSON.stringify(require('node:url').pathToFileURL(path.join(baseline.snapshot,name)).href)).replace('export function playEpilogue','function playEpilogue')+'\nglobalThis.play=playEpilogue;',context);
const panel=id=>({bg:id,rect:[0,0,100,100]});
const controller=context.play({scenes:[{page:true,panel:panel('a')},{panel:panel('b')},{page:true,panel:panel('c')}]},()=>{});
function advanceTo(at){wall=at;for(;;){const due=[...timers.entries()].filter(([,t])=>t.at<=wall).sort((a,b)=>a[1].at-b[1].at);if(!due.length)break;const [id,t]=due[0];timers.delete(id);t.fn();}}
controller.advance();const first=elements.find(e=>e.className==='ep-page');
advanceTo(100);controller.advance();assert.equal(first.children.length,2,'Same page retains both original panels');
advanceTo(200);controller.advance();const pages=elements.filter(e=>e.className==='ep-page');
assert.equal(pages.length,2);assert(first.classes.has('out'));assert(!first.removed);assert.equal(pages[1].children.length,1);
const snapshots=[];
for(const at of [200,259,260,270,346.6666667,359,360,400,459,460,500,546.6666667,590,619,620,633.3333333,650,699,700,720]){
 advanceTo(at);snapshots.push({at,retiredRemoved:first.removed,retiredOut:first.classes.has('out'),newPanelCount:pages[1].children.length});
}
const shakes=animations.filter(a=>a.className==='ep-page');
assert.equal(shakes.length,3);for(const animation of shakes){assert.equal(animation.options.duration,260);assert.equal(animation.options.delay,260);assert.deepEqual(animation.frames,[{translate:'0 0'},{translate:'.6vh -.4vh'},{translate:'-.4vh .3vh'},{translate:'0 0'}]);}
assert(source.includes('.ep-page{position:absolute;inset:0;transition:opacity .45s}'));
const report={result:'PASS',commit:baseline.commit,sourceHashes:{[name]:sha},snapshots,shakes,
 cssFadeSeconds:.45,cssFadeEasing:[.25,.1,.25,1],removeSeconds:.5,boundary:'Actual frozen playEpilogue with deterministic DOM, timers and animation recorder. Records authored WAAPI keyframes/options; CSS compositor, GPU and pixels are not executed.'};
fs.writeFileSync(path.join(root,'.tmp/source-epilogue-pages.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({result:report.result,snapshots:snapshots.length,shakes:shakes.length}));
