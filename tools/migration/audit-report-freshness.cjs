// Read only report inputs; does not alter a frozen package audit or run tests.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(__dirname,'audit-unified-snapshot.cjs'),'utf8');
const registry=source.slice(source.indexOf('const reports='),source.indexOf('const fixtures=[];'));
const {reports}=vm.runInNewContext(registry+';({reports})');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const rows=[];
for(const name of reports){
 const relative='docs/migration/evidence/'+name+'-offline.json',file=path.join(root,relative);
 const data=JSON.parse(fs.readFileSync(file,'utf8')),drift=[];let associations=0;
 for(const field of ['productionHashes','production','scripts','resources','inputs'])for(const [key,expected]of Object.entries(data[field]||{})){
  if(typeof expected!=='string'||!/^[a-f0-9]{64}$/i.test(expected))continue;
  const normalized=key.replaceAll('\\','/');
  const target=/^(scripts|assets|tools)\//.test(normalized)?normalized:(field==='resources'?'assets/':'scripts/')+normalized;
  const full=path.join(root,target),actual=fs.existsSync(full)?hash(full):null;
  associations++;if(actual!==expected)drift.push({path:target,expected,actual});
 }
 if(data.payslipTile){associations++;const {path:target,sha256:expected}=data.payslipTile,actual=hash(path.join(root,target));if(actual!==expected)drift.push({path:target,expected,actual});}
 rows.push({report:relative,reportSha256:hash(file),result:data.result??data.status??(data.pass===true?'PASS':'FAIL'),associations,drift});
}
const report={result:rows.some(r=>r.drift.length)?'STALE':'FRESH',rows,drift:rows.reduce((n,r)=>n+r.drift.length,0),boundary:'Current workspace versus registered report input hashes only. No package assertion and no behavioral rerun. Frozen package audits remain unchanged.'};
const out=path.join(root,process.argv[2]||'docs/migration/evidence/intro-next-report-freshness.json');
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({result:report.result,drift:report.drift,stale:rows.filter(r=>r.drift.length),evidence:out},null,2));
