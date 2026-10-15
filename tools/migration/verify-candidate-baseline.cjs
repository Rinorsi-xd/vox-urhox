// Read Git objects and extracted bytes; never updates source checkout or active.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),source='D:/Rino_Project/Vox';
const commit=process.argv[2];if(!/^[a-f0-9]{40}$/.test(commit||''))throw Error('Expected full commit');
const manifestPath=path.join(root,'docs/migration/baselines',commit+'.json');
const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const git=(...args)=>cp.execFileSync('git',args,{cwd:source,windowsHide:true,maxBuffer:32*1024*1024});
const active=path.join(root,'docs/migration/outgame-baseline.json');
const activeBefore=sha(fs.readFileSync(active));const headBefore=git('rev-parse','HEAD').toString().trim();
if(headBefore!==commit)throw Error('HEAD differs before verify');
const tree=git('ls-tree','-rz','--full-tree',commit).toString('utf8').split('\0').filter(Boolean).map(row=>{
 const split=row.indexOf('\t');const [mode,type,oid]=row.slice(0,split).split(' ');return {mode,type,oid,name:row.slice(split+1)};
});
const inputs=Buffer.from(tree.filter(x=>manifest.files[x.name]).map(x=>x.oid+'\n').join(''));
const blobs=cp.execFileSync('git',['cat-file','--batch'],{cwd:source,windowsHide:true,input:inputs,maxBuffer:1024*1024*1024});
let cursor=0;const verified={};
for(const entry of tree.filter(x=>manifest.files[x.name])){
 const end=blobs.indexOf(10,cursor);const header=blobs.subarray(cursor,end).toString().split(' ');const length=Number(header[2]);cursor=end+1;
 const bytes=blobs.subarray(cursor,cursor+length);cursor+=length+1;
 if(header[0]!==entry.oid||header[1]!=='blob')throw Error('Bad Git response '+entry.name);
 const record=manifest.files[entry.name],disk=fs.readFileSync(path.join(manifest.snapshot,entry.name));
 if(sha(disk)!==record.sha256||disk.length!==record.bytes)throw Error('Snapshot mismatch '+entry.name);
 const exact=disk.equals(bytes);
 const archiveCRLF=!exact&&!bytes.includes(0)&&Buffer.from(disk.toString('utf8').replaceAll('\r\n','\n'),'utf8').equals(bytes);
 if(!exact&&!archiveCRLF)throw Error('Git content mismatch '+entry.name);
 verified[entry.name]={gitBlob:entry.oid,gitSha256:sha(bytes),gitBytes:bytes.length,sha256:record.sha256,bytes:record.bytes,archiveCRLF};
}
if(Object.keys(verified).length!==Object.keys(manifest.files).length)throw Error('Manifest includes nontracked file');
const headAfter=git('rev-parse','HEAD').toString().trim(),activeAfter=sha(fs.readFileSync(active));
if(headAfter!==headBefore||activeAfter!==activeBefore)throw Error('Source HEAD or active manifest changed');
const recordHash=sha(Buffer.from(JSON.stringify(manifest.files)));
if(recordHash!==manifest.contentSha256)throw Error('Manifest content hash differs');
const omitted=tree.filter(x=>!manifest.files[x.name]).map(x=>x.name);
const report={result:'PASSED',commit,headBefore,headAfter,manifest:manifestPath,snapshot:manifest.snapshot,activeBefore,activeAfter,contentSha256:recordHash,
 verifiedFiles:Object.keys(verified).length,archiveCRLFFiles:Object.values(verified).filter(x=>x.archiveCRLF).length,verifiedBytes:Object.values(verified).reduce((a,x)=>a+x.bytes,0),repositoryTrackedFiles:tree.length,omittedTrackedFiles:omitted.length,omittedRoots:[...new Set(omitted.map(x=>x.split('/')[0]))],verified};
const out=path.join(root,'docs/migration/evidence/candidate-baseline-'+commit.slice(0,12)+'.json');fs.writeFileSync(out,JSON.stringify(report,null,2));
console.log(JSON.stringify({...report,verified:undefined,evidence:out},null,2));
