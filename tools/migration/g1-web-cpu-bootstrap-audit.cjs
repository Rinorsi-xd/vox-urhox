'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),zlib=require('node:zlib');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
async function audit(file,base){
 const fixture=JSON.parse(fs.readFileSync(file)),source=JSON.parse(fs.readFileSync(fixture.g1WebCpu.sourceFrozen));
 const dist=path.join(fixture.source_directory,'dist'),manifestBytes=fs.readFileSync(fixture.manifest_path),manifest=JSON.parse(manifestBytes),latest=JSON.parse(fs.readFileSync(path.join(dist,'latest.json')));
 const urls=[],checks=[];
 for(const [relative,expected]of Object.entries(fixture.g1WebCpu.bootstrapFiles)){
  const bytes=fs.readFileSync(path.join(dist,relative));assert.equal(sha(bytes),expected);checks.push(relative);urls.push(['/game-dist/'+relative,expected]);
  if(relative.endsWith('project.json'))assert.deepEqual(bytes,fs.readFileSync(path.join(source.source_directory,'dist',relative)),'Preserve actual project metadata');
  else assert.deepEqual(JSON.parse(bytes),latest,'Version aliases must identify the same derived manifest');
 }
 assert.equal(latest.client,zlib.crc32(manifestBytes).toString(16).padStart(8,'0'));
 urls.push(['/game-dist/'+path.relative(dist,fixture.manifest_path).replaceAll('\\','/'),sha(manifestBytes)]);
 let locals=0,externals=0;for(const row of manifest.files){if(row.source){externals++;continue}const filename=row.uuid+'-'+row.hash+row.ext,stat=fs.statSync(path.join(dist,'assets',filename));assert(stat.isFile());assert.equal(stat.size,row.size,'Local resource size '+row.fs_path);locals++;
  if(row.fs_path==='main.lua')urls.push(['/game-dist/assets/'+filename,fixture.g1WebCpu.entrySha256]);
 }
 const cached=require('./cached-engine-sources.cjs');let cachedChecks=0;
 for(const [name,pin]of Object.entries(cached.snapshots)){
  const tag='https://tapcode-sce.spark.xd.com/src/'+name+'/stable.json',tagResult=cached.read(tag);assert(tagResult,'Pinned '+name+' tag');assert.equal(JSON.parse(tagResult.body).client,pin.client);cachedChecks++;
  urls.push(['/cached-engine-source/src/'+name+'/stable.json',sha(tagResult.body)]);
  const address='https://tapcode-sce.spark.xd.com/src/'+name+'/'+pin.version+'/manifest-'+pin.client+'.json',response=cached.read(address);assert(response,'Pinned '+name+' manifest');const remote=JSON.parse(response.body);cachedChecks++;
  urls.push(['/cached-engine-source/src/'+name+'/'+pin.version+'/manifest-'+pin.client+'.json',sha(response.body)]);
  if(name==='engine-startup')for(const row of remote.files.filter(row=>!row.source&&row.groups?.includes('#blocking'))){
   const relative='/src/'+name+'/assets/'+row.uuid+'-'+row.hash+row.ext,response=cached.read('https://tapcode-sce.spark.xd.com'+relative);assert(response,'Pinned startup resource '+relative);assert.equal(response.body.length,row.size);cachedChecks++;
   urls.push(['/cached-engine-source'+relative,sha(response.body)]);
  }
 }
 for(const name of ['UrhoXRuntime.js','UrhoXRuntime.wasm','UrhoXRuntime.data']){const p=path.resolve(__dirname,'../../.tmp/web-engine',name);assert(fs.statSync(p).size>0);urls.push(['/'+name,sha(fs.readFileSync(p))]);}
 const http=[];if(base)for(const [url,expected]of urls){const response=await fetch(base+url);assert.equal(response.status,200,'Bootstrap URL '+url);const bytes=Buffer.from(await response.arrayBuffer());assert.equal(sha(bytes),expected,'HTTP identity '+url);http.push({url,status:response.status,sha256:expected,bytes:bytes.length})}
 return {status:'PASS',sourceFrozen:fixture.g1WebCpu.sourceFrozen,fixture:file,localResources:locals,externalReferences:externals,bootstrapFiles:checks,cachedChecks,http,
  boundary:'No browser or engine execution. All local payload sizes, project metadata provenance, version aliases, blocking startup scripts and selected bootstrap HTTP byte identities checked. Two ungrouped review UI images are not used by this skip-login non-review first-Web-boot path and are not checked. Does not prove dynamic Lua initialization.'};
}
module.exports={audit};
if(require.main===module)audit(process.argv[2],process.argv[3]).then(result=>{
 if(process.argv[4]){const file=path.resolve(process.argv[4]);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({status:result.status,file,localResources:result.localResources,http:result.http.length}))}
 else console.log(JSON.stringify(result,null,2));
}).catch(error=>{console.error(error.stack);process.exitCode=1});
