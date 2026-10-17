'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const ev=path.join(root,'docs/migration/evidence/wasm-release-cluster-1017-a');
const wasm=fs.readFileSync(path.join(root,'.tmp/web-engine/UrhoXRuntime.wasm'));
assert.equal(sha(wasm),'4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765');
const reference=path.join(root,'.tmp/lua-release-reference-1017/lua-5.4.8');
const source=fs.readFileSync(path.join(reference,'src/lgc.c'),'utf8');
const checks=[];
function check(name,actual,expected){assert.deepEqual(actual,expected,name);checks.push({name,actual,expected});}
function wat(id){return fs.readFileSync(path.join(ev,'function-'+id+'.wat'),'utf8');}
function count(s,re){return [...s.matchAll(re)].length;}
const step=wat(1680),sweep=wat(5650),free=wat(7185),mark=wat(10056);
check('step has three markold call sites',count(step,/\bcall 10056\b/g),3);
check('step has five sweepgen call sites',count(step,/\bcall 5650\b/g),5);
check('step has gcstop debt -2000',/i32\.load8_u offset=82[\s\S]*?i32\.const -2000\s+call 4125/.test(step),true);
check('step dispatches generational kind byte',/i32\.load8_u offset=78\s+i32\.const 1\s+i32\.ne/.test(step),true);
check('sweep frees white objects through candidate freeobj',/i32\.load8_u offset=5[\s\S]*?i32\.const 24[\s\S]*?call 7185/.test(sweep),true);
check('sweep reads seven-age transition table',/i32\.load8_u offset=2046776/.test(sweep),true);
check('markold changes age3 to age4 by xor7',/i32\.const 3\s+i32\.ne[\s\S]*?i32\.const 7\s+i32\.xor/.test(mark),true);
check('markold black bit32 invokes marker',/i32\.const 32\s+i32\.and[\s\S]*?call 1430/.test(mark),true);
check('freeobj switches object tag offset4',/i32\.load8_u offset=4/.test(free)&&/br_table/.test(free),true);
check('freeobj repeated allocator-free callsites',count(free,/\bcall 1593\b/g),17);
check('reference has luaC_step debt sentinel',/luaE_setdebt\(g, -2000\)/.test(source),true);
const young=source.slice(source.indexOf('static void youngcollection ('),source.indexOf('static void youngcollection (')+2300);
check('reference youngcollection has five sweeps',count(young,/\bsweepgen\(/g),5);
check('runtime identifies Lua54 generational collector',wasm.includes(Buffer.from('Lua 5.4: Generational GC enabled.')),true);
let cursor=8;
function u(){let n=0,s=0,b;do{b=wasm[cursor++];n+=(b&127)*2**s;s+=7;}while(b&128);return n;}
function signed(){let n=0,s=0,b;do{b=wasm[cursor++];n|=(b&127)<<s;s+=7;}while(b&128);return s<32&&(b&64)?n|(-1<<s):n;}
let age;const segments=[];
while(cursor<wasm.length){const kind=wasm[cursor++],size=u(),end=cursor+size;if(kind===11){const n=u();for(let i=0;i<n;i++){const flag=u();let base=null;if(flag===2)u();if(flag!==1){assert.equal(wasm[cursor++],0x41);base=signed();assert.equal(wasm[cursor++],0x0b);}const len=u();segments.push(wasm.subarray(cursor,cursor+len));if(base!==null&&base<=2046776&&base+len>=2046783)age=[...wasm.subarray(cursor+2046776-base,cursor+2046783-base)];cursor+=len;}}cursor=end;}
const init=fs.readFileSync(path.join(root,'docs/migration/evidence/wasm-release-cluster-1017-init/function-40647.wat'),'utf8');
let ageLocation;
for(const m of init.matchAll(/i32\.const (\d+)\s+i32\.const (\d+)\s+i32\.const (\d+)\s+memory\.init (\d+)/g)){
 const base=+m[1],sourceOffset=+m[2],len=+m[3],index=+m[4];
 if(base<=2046776&&base+len>=2046783){age=[...segments[index].subarray(sourceOffset+2046776-base,sourceOffset+2046783-base)];ageLocation={segment:index,base,sourceOffset,length:len};}
}
check('exact WASM age table equals Lua54 sweepgen nextage',age,[1,3,3,4,4,5,6]);
const inputs={wasm:sha(wasm),referenceArchive:sha(fs.readFileSync(path.join(path.dirname(reference),'lua-5.4.8.tar.gz'))),referenceLgc:sha(Buffer.from(source))};
inputs.startFunction40647=sha(Buffer.from(init));
for(const id of [1680,5650,7185,10056])inputs['function-'+id]=sha(Buffer.from(wat(id)));
const output={status:'PASS_STRUCTURAL_LUA54_GC_CORRESPONDENCE',inputs,checks,ageLocation,
 mappings:[{id:1680,source:'luaC_step with inlined generational/incremental step and youngcollection'},{id:5650,source:'sweepgen'},{id:7185,source:'freeobj'},{id:10056,source:'markold'}],
 source:{url:'https://www.lua.org/ftp/lua-5.4.8.tar.gz',role:'Public Lua5.4 family structural reference only; runtime exact patch version remains UNKNOWN.'},
 boundary:'Original symbols are stripped. This is a corroborated structural identification, not recovered original debug names. It identifies sampled collector work, not the originating allocation owners, total GC duration on every frame, or an optimization benefit. No target execution, collector mutation, game or hardware run.'};
fs.writeFileSync(path.join(ev,'lua-gc-corroboration.json'),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(output,null,2));
