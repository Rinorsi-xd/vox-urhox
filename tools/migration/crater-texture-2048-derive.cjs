'use strict';
// Derive a single-resource package without rebuilding or modifying its freeze.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),zlib=require('node:zlib');
const root=path.resolve(__dirname,'../..'),resource='Crater/texture-2.png';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const crc=b=>zlib.crc32(b).toString(16).padStart(8,'0');
const bytes=p=>fs.readFileSync(p),read=p=>JSON.parse(bytes(p).toString('utf8').replace(/^\uFEFF/,''));
function plan(candidateFile){
 candidateFile=path.resolve(root,candidateFile);const candidate=read(candidateFile);
 assert.equal(candidate.status,'PREPARED_NOT_RUN');assert.equal(candidate.resource,resource);
 const identityBytes=bytes(candidate.sourceIdentity);assert.equal(sha(identityBytes),candidate.sourceIdentitySha256);
 const before=JSON.parse(identityBytes),dist=path.join(before.source_directory,'dist');
 assert(before.ok&&!before.g1WebCpu,'Normal frozen gameplay package required');
 const manifestBytes=bytes(before.manifest_path);assert.equal(sha(manifestBytes),candidate.sourceManifestSha256);
 const manifest=JSON.parse(manifestBytes);assert.equal(manifest.assets_pak,0);
 const original=manifest.files.find(r=>r.fs_path===resource);assert.deepEqual(original,candidate.resourceEntry);
 const oldName=original.uuid+'-'+original.hash+original.ext,old=bytes(path.join(dist,'assets',oldName));
 assert.equal(sha(old),candidate.source.sha256);assert.equal(crc(old),original.hash);assert.equal(old.length,original.size);
 const image=bytes(candidate.candidate.path);assert.equal(sha(image),candidate.candidate.sha256);assert.equal(crc(image),candidate.candidate.crc32);assert.equal(image.length,candidate.candidate.bytes);
 assert.equal(image.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.equal(image.readUInt32BE(16),2048);assert.equal(image.readUInt32BE(20),2048);assert.equal(image[24],8);assert.equal(image[25],6);
 const sidecar=manifest.files.find(r=>r.fs_path===candidate.sidecar.resource);
 assert.equal(sha(bytes(path.join(dist,'assets',sidecar.uuid+'-'+sidecar.hash+sidecar.ext))),candidate.sidecar.sha256);
 let localPayloads=0;for(const row of manifest.files){if(row.source)continue;const file=path.join(dist,'assets',row.uuid+'-'+row.hash+row.ext);assert.equal(fs.statSync(file).size,row.size,'Frozen payload '+row.fs_path);localPayloads++;}
 let scripts=0;for(const[name,expected]of Object.entries(before.identity.scripts)){
  assert.equal(sha(bytes(path.join(before.source_directory,'scripts',name))),expected,'Frozen source '+name);
  const row=manifest.files.find(r=>r.fs_path===name);assert(row);
  assert.equal(sha(bytes(path.join(dist,'assets',row.uuid+'-'+row.hash+row.ext))),expected,'Frozen packaged '+name);scripts++;
 }
 const next=structuredClone(manifest),changed=next.files.find(r=>r.fs_path===resource);changed.hash=crc(image);changed.size=image.length;
 assert.equal(next.files.length,manifest.files.length);let differences=0;
 for(let i=0;i<manifest.files.length;i++){if(JSON.stringify(manifest.files[i])!==JSON.stringify(next.files[i])){assert.equal(manifest.files[i].fs_path,resource);differences++;}}
 assert.equal(differences,1,'Single changed resource');
 const originalLatest=read(path.join(dist,'latest.json'));const encoded=Buffer.from(JSON.stringify(next));
 const latest={...originalLatest,client:crc(encoded)};
 return {candidateFile,candidate,before,dist,manifest,next,encoded,latest,image,oldName,
  newName:changed.uuid+'-'+changed.hash+changed.ext,scripts,localPayloads};
}
function prepare(candidateFile,destination){
 const p=plan(candidateFile),out=path.resolve(root,destination);
 assert(out.startsWith(path.join(root,'.tmp')+path.sep)&&!fs.existsSync(out),'Fresh project .tmp destination required');
 const aliases=['latest.json',p.latest.version+'/version.json',p.latest.version.split('.')[0]+'.x.x.json'];
 const originalManifest=path.relative(p.dist,p.before.manifest_path).replaceAll('\\','/');
 const skip=new Set([...aliases,originalManifest,'assets/'+p.oldName]);let links=0;
 function linkTree(from,to,relative=''){
  fs.mkdirSync(to,{recursive:true});
  for(const entry of fs.readdirSync(from,{withFileTypes:true})){
   assert(!entry.isSymbolicLink(),'No ambiguous linked source paths');const rel=relative?relative+'/'+entry.name:entry.name;
   if(skip.has(rel))continue;const a=path.join(from,entry.name),b=path.join(to,entry.name);
   if(entry.isDirectory())linkTree(a,b,rel);else {fs.linkSync(a,b);links++;}
  }
 }
 fs.mkdirSync(out);fs.cpSync(path.join(p.before.source_directory,'scripts'),path.join(out,'scripts'),{recursive:true});
 fs.cpSync(path.join(p.before.source_directory,'.project'),path.join(out,'.project'),{recursive:true});
 const liveResource=path.join(p.before.source_directory,'assets',resource);
 assert.equal(sha(bytes(liveResource)),p.candidate.source.sha256,'Frozen loose asset identity');
 const sourceSkip=new Set([resource]);
 function linkAssets(from,to,relative=''){
  fs.mkdirSync(to,{recursive:true});for(const entry of fs.readdirSync(from,{withFileTypes:true})){
   assert(!entry.isSymbolicLink());const rel=relative?relative+'/'+entry.name:entry.name;
   if(sourceSkip.has(rel))continue;const a=path.join(from,entry.name),b=path.join(to,entry.name);
   if(entry.isDirectory())linkAssets(a,b,rel);else fs.linkSync(a,b);
  }
 }
 linkAssets(path.join(p.before.source_directory,'assets'),path.join(out,'assets'));
 fs.writeFileSync(path.join(out,'assets',resource),p.image);
 const outputDist=path.join(out,'dist');linkTree(p.dist,outputDist);
 fs.writeFileSync(path.join(outputDist,'assets',p.newName),p.image);
 const manifestPath=path.join(outputDist,p.latest.version,'manifest-'+p.latest.client+'.json');
 fs.mkdirSync(path.dirname(manifestPath),{recursive:true});fs.writeFileSync(manifestPath,p.encoded);
 for(const name of aliases)fs.writeFileSync(path.join(outputDist,name),JSON.stringify(p.latest));
 const report={status:'DERIVED_NOT_RUN',sourceIdentity:p.candidate.sourceIdentity,candidate:p.candidateFile,
  resource,sourceSha256:p.candidate.source.sha256,candidateSha256:p.candidate.candidate.sha256,
  beforeBytes:p.candidate.source.bytes,afterBytes:p.image.length,scriptChanges:0,manifestResourceChanges:1,
  scriptsVerified:p.scripts,localPayloadSizesVerified:p.localPayloads,linkedDistFiles:links,
  boundary:'Single bake payload and its manifest hash/size changed. Material/sidecar/UV/physics/all scripts unchanged. Shared hardlinks are read-only by convention; never rebuild or overwrite this derived snapshot. No Runtime, visual or performance acceptance.'};
 const prepared={...p.before,source_directory:out,manifest_path:manifestPath,log_path:path.join(out,'derivation.json'),assetDerivative:report};
 fs.writeFileSync(path.join(out,'derivation.json'),JSON.stringify(report,null,2)+'\n');
 fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(prepared,null,2)+'\n');
 assert.equal(sha(bytes(p.candidate.sourceIdentity)),p.candidate.sourceIdentitySha256,'Original identity untouched');
 assert.equal(sha(bytes(p.before.manifest_path)),p.candidate.sourceManifestSha256,'Original manifest untouched');
 assert.equal(sha(bytes(liveResource)),p.candidate.source.sha256,'Original loose asset untouched');
 assert.equal(sha(bytes(path.join(p.dist,'assets',p.oldName))),p.candidate.source.sha256,'Original payload untouched');
 return {report,identity:path.join(out,'identity.json')};
}
module.exports={plan,prepare};
if(require.main===module){try{
 const candidate=process.argv[2];assert(candidate,'candidate.json [fresh .tmp destination | --check-only]');
 if(process.argv[3]==='--check-only'){
  const p=plan(candidate);console.log(JSON.stringify({status:'PASS_NOT_DERIVED',scripts:p.scripts,localPayloads:p.localPayloads,resourceChanges:1,scriptChanges:0,candidateSha256:p.candidate.candidate.sha256,nextManifest:crc(p.encoded)}));
 }else {assert(process.argv[3],'Explicit output directory required');console.log(JSON.stringify(prepare(candidate,process.argv[3])));}
}catch(error){console.error(error.stack);process.exitCode=1}}
