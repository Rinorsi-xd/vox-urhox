// Freeze only migration inputs. Verify originals again after copying because
// the H5 checkout may be edited while this process runs.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const source='D:/Rino_Project/Vox',target=path.resolve(__dirname,'../..');
const refIndex=process.argv.indexOf('--ref');
const requestedRef=refIndex>=0?process.argv[refIndex+1]:null;
if(refIndex>=0&&!requestedRef)throw Error('--ref requires a Git commit or branch');
const git=(...args)=>cp.execFileSync('git',args,{cwd:source,encoding:'utf8',windowsHide:true}).trim();
const commit=git('rev-parse','--verify',requestedRef?requestedRef+'^{commit}':'HEAD');
const stamp=new Date().toISOString().replace(/[:.]/g,'-');
const destination=path.join(target,'.tmp','outgame-source-'+stamp);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const files={};
let input=source;
if(requestedRef){
 const archive=path.join(target,'.tmp','h5-baseline-'+commit.slice(0,12)+'.tar');
 fs.mkdirSync(path.dirname(archive),{recursive:true});
 const entries=['shared','three','docs','策划案','AGENTS.md','README.md','project.yaml','review/performance'];
 const tracked=entries.filter(name=>git('ls-tree','--name-only',commit,'--',name));
 cp.execFileSync('git',['archive','--format=tar','--output='+archive,commit,...tracked],{cwd:source,windowsHide:true});
 fs.mkdirSync(destination,{recursive:true});
 // Python's tar reader preserves Git's UTF-8 filenames on Windows.
 cp.execFileSync(process.env.VOX_MAKER_PYTHON||'python',['-m','tarfile','--filter=data','-e',archive,destination],{windowsHide:true});
 input=destination;
}
function copy(relative){
 const from=path.join(input,relative);
 if(fs.statSync(from).isDirectory()){for(const name of fs.readdirSync(from))copy(path.join(relative,name));return;}
 const bytes=fs.readFileSync(from),to=path.join(destination,relative);
 if(input!==destination){fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,bytes);}
 files[relative.replaceAll('\\','/')]={sha256:hash(bytes),bytes:bytes.length};
}
for(const entry of requestedRef?fs.readdirSync(destination):['shared','three/src','three/vendor','three/index.html'])copy(entry);
if(!requestedRef){
 for(const [name,record]of Object.entries(files))if(hash(fs.readFileSync(path.join(source,name)))!==record.sha256)throw Error('Source changed while freezing: '+name);
 if(git('rev-parse','HEAD')!==commit)throw Error('Source HEAD changed while freezing');
}
const manifest={schema:1,source,branch:requestedRef||git('branch','--show-current'),commit,subject:git('log','-1','--format=%s',commit),
 frozenAt:new Date().toISOString(),snapshot:destination,workingTree:git('status','--porcelain=v1'),
 scope:['garage','builder','inventory','weapons and model presentation','creative workshop'],excluded:['tutorial','combat simulation','endless mode'],files};
manifest.sourceMode=requestedRef?'git-commit':'working-tree';
manifest.includesWorkingTreeChanges=!requestedRef;
if(requestedRef){manifest.scope=['full H5 Git baseline'];manifest.excluded=[];}
manifest.contentSha256=hash(Buffer.from(JSON.stringify(files)));
fs.mkdirSync(path.join(target,'docs/migration'),{recursive:true});
const active=path.join(target,'docs/migration/outgame-baseline.json');
if(fs.existsSync(active)){
 const previous=JSON.parse(fs.readFileSync(active,'utf8'));
 const saved=path.join(target,'docs/migration/baselines',previous.commit+'.json');
 fs.mkdirSync(path.dirname(saved),{recursive:true});if(!fs.existsSync(saved))fs.copyFileSync(active,saved);
}
fs.writeFileSync(active,JSON.stringify(manifest,null,2));
console.log(JSON.stringify({snapshot:destination,branch:manifest.branch,commit:manifest.commit,contentSha256:manifest.contentSha256,files:Object.keys(files).length,bytes:Object.values(files).reduce((s,v)=>s+v.bytes,0)},null,2));
