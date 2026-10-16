// Compare frozen authored content separately from regenerated UUID metadata.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const before=path.resolve(root,process.argv[2]);
const after=path.resolve(root,process.argv[3]);
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function files(base){
 const rows={};
 for(const group of ['scripts','assets']){
  const directory=path.join(base,group);
  for(const e of fs.readdirSync(directory,{recursive:true,withFileTypes:true})){
   if(!e.isFile())continue;
   const file=path.join(e.parentPath,e.name),name=path.relative(base,file).replaceAll('\\','/');
   rows[name]=hash(file);
  }
 }
 return rows;
}
const oldFiles=files(before),newFiles=files(after),changes=[];
for(const name of new Set([...Object.keys(oldFiles),...Object.keys(newFiles)])){
 if(oldFiles[name]!==newFiles[name])changes.push({path:name,before:oldFiles[name]||null,after:newFiles[name]||null});
}
function manifest(base){
 const identity=JSON.parse(fs.readFileSync(path.join(base,'identity.json'),'utf8'));
 return {identity:identity.identity,path:identity.manifest_path,data:JSON.parse(fs.readFileSync(identity.manifest_path,'utf8'))};
}
const a=manifest(before),b=manifest(after);
function normalized(man){
 const paths=new Map(man.files.map(row=>[row.uuid,row.fs_path]));
 return new Map(man.files.map(row=>{
  const copy={...row};delete copy.uuid;delete copy.hash;
  if(copy.refs)copy.refs=copy.refs.map(id=>paths.get(id)||'external:'+id).sort();
  if(copy.groups)copy.groups=[...copy.groups].sort();
  return [row.fs_path,copy];
 }));
}
const am=normalized(a.data),bm=normalized(b.data),manifestChanges=[];
for(const name of new Set([...am.keys(),...bm.keys()])){
 if(JSON.stringify(am.get(name))!==JSON.stringify(bm.get(name)))manifestChanges.push({path:name,before:am.get(name)||null,after:bm.get(name)||null});
}
const content=changes.filter(row=>!row.path.endsWith('.meta'));
const metadata=changes.filter(row=>row.path.endsWith('.meta'));
const report={before,after,sourceCommit:b.identity.sourceCommit,manifest:path.basename(b.path),
 counts:{beforeFiles:Object.keys(oldFiles).length,afterFiles:Object.keys(newFiles).length,contentChanges:content.length,
  scriptContentChanges:content.filter(row=>row.path.startsWith('scripts/')).length,
  assetContentChanges:content.filter(row=>row.path.startsWith('assets/')).length,
  metadataChanges:metadata.length,scriptMetadataChanges:metadata.filter(row=>row.path.startsWith('scripts/')).length,
  assetMetadataChanges:metadata.filter(row=>row.path.startsWith('assets/')).length,normalizedManifestChanges:manifestChanges.length},
 content,metadata,normalizedManifestChanges:manifestChanges,
 boundary:'Actual SHA256 of every scripts/assets file in both frozen snapshots, including added/removed files. Metadata UUID changes are reported separately. Manifest comparison normalizes refs to fs_path and excludes row UUID/hash only. This is content identity, not behavior or runtime acceptance.'};
const output=path.join(root,'docs/migration/evidence/snapshot-'+path.basename(b.path,'.json')+'-delta.json');
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,metadata:undefined,normalizedManifestChanges:undefined,evidence:output},null,2));
