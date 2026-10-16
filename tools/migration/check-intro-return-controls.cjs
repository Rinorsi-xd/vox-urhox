// CPU controls only: this does not launch or accept the actual opening.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {RunOptions,CheckReturnRoute}=require('./check-intro-natural-web.cjs');
const root=path.resolve(__dirname,'../..'),target=path.join(__dirname,'check-intro-natural-web.cjs');
let checks=0;
function check(ok,label){assert.ok(ok,label);checks++;}
const full=RunOptions({}),boot=RunOptions({VOX_INTRO_BOOT_ONLY:'1'}),route=RunOptions({VOX_INTRO_RETURN_ONLY:'1'});
check(full.scope==='full-natural-opening'&&!full.returnOnly&&!full.bootOnly,'default keeps full natural scope');
check(full.prefix==='intro-natural-web','default evidence prefix unchanged');
check(boot.scope==='opening-boot-only'&&boot.bootOnly&&!boot.returnOnly,'boot scope unchanged');
check(route.scope==='public-ad-skip-contract-gate-return'&&route.returnOnly&&!route.bootOnly,'explicit return-only scope');
check(route.prefix==='intro-return-web'&&route.prefix!==full.prefix,'return-only evidence cannot overwrite natural opening evidence');
check(!RunOptions({VOX_INTRO_RETURN_ONLY:'true'}).returnOnly,'only explicit 1 selects return-only');
assert.throws(()=>RunOptions({VOX_INTRO_RETURN_ONLY:'1',VOX_INTRO_BOOT_ONLY:'1'}),/mutually exclusive/);checks++;
const samples=[{stage:'ad',shot:'logo'},{stage:'reality',shot:'tvcut'},{stage:'reality',shot:'comms',line:'v07'},{stage:'reality',shot:'contract'}];
const evidence={skipStage:'ad',skipKey:'Escape',realityObserved:true,choiceKey:'3',choiceReply:'v07'};
CheckReturnRoute(samples,evidence,check);
const rejects=[
 ['wrong skip stage',samples,{...evidence,skipStage:'boot'}],
 ['nonpublic skip',samples,{...evidence,skipKey:'injected'}],
 ['missing actual reality',samples,{...evidence,realityObserved:false}],
 ['missing actual comms',samples.filter(s=>s.shot!=='comms'),evidence],
 ['wrong actual choice',samples,{...evidence,choiceKey:'2'}],
 ['missing actual response',samples,{...evidence,choiceReply:'v06'}],
 ['missing actual contract',samples.filter(s=>s.shot!=='contract'),evidence],
 ['driving wrongly included',samples.concat({shot:'sortie-play'}),evidence],
 ['montage wrongly included',samples.concat({shot:'m-drive'}),evidence],
];
for(const [label,trace,proof]of rejects){assert.throws(()=>CheckReturnRoute(trace,proof,(ok,text)=>assert.ok(ok,text)),undefined,label);checks++;}
const code=fs.readFileSync(target,'utf8'),first=code.indexOf("  check(Date.now()-started>110000"),last=code.indexOf('\n  }else CheckReturnRoute',first);
const originalBlock=code.slice(first,last+1).replace(/\r\n/g,'\n');
const fullAssertionsSha=crypto.createHash('sha256').update(originalBlock).digest('hex');
check(first>0&&last>first,'full natural assertions remain separate from return-only');
check(fullAssertionsSha==='3c2da6d890597d2a8eb26cd10b5c61402c826a2f3871bbb9e837b3f79d036465','all original full natural assertions preserved byte-for-byte after line-ending normalization');
check(code.includes("if(!returnOnly){\n  check(Date.now()-started>110000")||code.includes("if(!returnOnly){\r\n  check(Date.now()-started>110000"),'full natural assertions execute by default');
check(code.includes("if(require.main===module)Run()"),'CPU import does not launch browser or run game');
const report={result:'PASS',scope:'CPU return-only QA controls; no runtime, visuals or continuity acceptance',checks,negativeControls:rejects.map(r=>r[0]),fullAssertionsSha,toolSha:crypto.createHash('sha256').update(code).digest('hex')};
fs.writeFileSync(path.join(root,'docs/migration/evidence/intro-return-controls-offline.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
