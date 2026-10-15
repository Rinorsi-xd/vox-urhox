// Execute the frozen production help builder, then parse its actual DOM.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
if(!vm.SourceTextModule){
 const r=require('node:child_process').spawnSync(process.execPath,['--experimental-vm-modules',__filename,...process.argv.slice(2)],{stdio:'inherit'});
 process.exit(r.status??1);
}
const root=path.resolve(__dirname,'../..');
const {chromium}=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
async function main(){
 const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
 const relative='shared/ui/ui.js',source=fs.readFileSync(path.resolve(root,baseline.snapshot,relative),'utf8');
 const sha256=crypto.createHash('sha256').update(source).digest('hex');assert.equal(sha256,baseline.files[relative].sha256);
 let html='';const box={set innerHTML(value){html=value;},addEventListener(){}};
 const context=vm.createContext({document:{querySelector(selector){assert.equal(selector,'#help');return box;}}});
 const module=new vm.SourceTextModule(source,{context});
 // None of these imported gameplay functions run in _help; unexpected calls fail.
 const exports=['ROTOR_MODES','PARTS','PALETTE','TIERS','CELL','icon','tierBadge','sfx','uiCoordinates'];
 const dependency=new vm.SyntheticModule(exports,function(){for(const name of exports)this.setExport(name,()=>{throw Error('Unexpected help dependency '+name);});},{context});
 await module.link(()=>dependency);await module.evaluate();module.namespace.UI.prototype._help.call({});
 assert(html.includes('操作说明'));
 const browser=await chromium.launch({headless:true,channel:'chrome'});let groups;
 try{const page=await browser.newPage();await page.setContent(html);
  groups=await page.locator('.cols section').evaluateAll(sections=>sections.map(section=>({title:section.querySelector('h3').textContent,
   rows:[...section.querySelectorAll('.row')].map(row=>[row.querySelector('kbd').textContent,row.querySelector('span').textContent])})));
 }finally{await browser.close();}
 assert.equal(groups.length,5);assert.equal(groups.reduce((n,g)=>n+g.rows.length,0),48);
 const output=path.join(root,'assets/UI/SourceHelp.json'),before=JSON.parse(fs.readFileSync(output,'utf8'));
 const matches=JSON.stringify(before)===JSON.stringify(groups);
 const evidence={baseline:baseline.commit,source:relative,sourceSha256:sha256,groups:groups.length,rows:groups.reduce((n,g)=>n+g.rows.length,0),
  previousRows:before.reduce((n,g)=>n+g.rows.length,0),matchesBefore:matches,mode:process.argv.includes('--write')?'import':'check',
  boundary:'Only source help content extraction; does not prove corresponding controls or rendered font/layout parity.'};
 if(process.argv.includes('--write'))fs.writeFileSync(output,JSON.stringify(groups,null,2)+'\n');else assert(matches,'Help resource differs from frozen production UI');
 fs.writeFileSync(path.join(root,'docs/migration/evidence/source-help-baseline-'+(evidence.mode==='import'?'import':'check')+'.json'),JSON.stringify(evidence,null,2)+'\n');
 console.log(JSON.stringify(evidence));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
