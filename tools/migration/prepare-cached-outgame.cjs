// Local visual QA fixture. Uses Maker's builder and downloaded client manifests.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {execFile}=require('node:child_process'),{promisify}=require('node:util');
const cache=require('./cached-engine-sources.cjs');
const root=path.resolve(__dirname,'../..');
async function main(){
 const python=process.env.VOX_MAKER_PYTHON,builder=process.env.VOX_MAKER_BUILDER;
 if(!python||!builder)throw Error('Set VOX_MAKER_PYTHON and VOX_MAKER_BUILDER to the installed Maker runtime paths.');
 const source=path.join(root,'.tmp/outgame-cached-'+Date.now());fs.mkdirSync(source,{recursive:true});
 for(const name of ['scripts','assets','.project'])fs.cpSync(path.join(root,name),path.join(source,name),{recursive:true});
 const server=http.createServer((req,res)=>{
  const cached=cache.read('https://tapcode-sce.spark.xd.com'+req.url);
  if(!cached)return res.writeHead(404).end();
  let body=cached.body;
  if(/\/(stable|latest)\.json/.test(req.url)){
   const tag=JSON.parse(body);delete tag.server;body=JSON.stringify(tag);
  }
  res.setHeader('Content-Type','application/json');res.end(body);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try{
  const config=JSON.parse(fs.readFileSync(path.join(source,'.project/settings.json'),'utf8'));
  config.sources=Object.fromEntries(['engine-res','official-res'].map(name=>[name,{tag:'stable',base_url:'http://127.0.0.1:'+server.address().port+'/src/'+name+'/'}]));
  fs.writeFileSync(path.join(source,'.project/settings.json'),JSON.stringify(config));
  const result=await promisify(execFile)(python,[builder,'--project',source,'--force-enhanced-refs','--no-7z','--no-compress'],{cwd:path.dirname(builder),windowsHide:true,timeout:300000,maxBuffer:8*1024*1024,env:{...process.env,PYTHONIOENCODING:'utf-8',PYTHONNOUSERSITE:'1'}});
  fs.writeFileSync(path.join(source,'prepare.log'),result.stdout+result.stderr);
  if(/加载远端来源.*失败|无法获取 version.json|无法下载 manifest/.test(result.stdout))throw Error('Cached client manifest preparation failed; see '+source+'/prepare.log');
  const dist=path.join(source,'dist'),tag=JSON.parse(fs.readFileSync(path.join(dist,'latest.json')));
  const manifestPath=path.join(dist,tag.version,'manifest-'+tag.client+'.json');
  const manifest=JSON.parse(fs.readFileSync(manifestPath));
  // The temporary mirror closes after building; runtime requests use the explicit cache route.
  for(const [name,spec] of Object.entries(manifest.sources))spec.base_url='https://tapcode-sce.spark.xd.com/src/'+name+'/';
  fs.writeFileSync(manifestPath,JSON.stringify(manifest));
  if(!manifest.files.some(f=>f.fs_path==='UI/SalvageRules.json'))throw Error('SalvageRules missing from current package');
  const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json'),'utf8'));
  const scripts={};
  for(const item of fs.readdirSync(path.join(source,'scripts'),{recursive:true,withFileTypes:true})){
   if(!item.isFile()||!item.name.endsWith('.lua'))continue;
   const file=path.join(item.parentPath,item.name),relative=path.relative(path.join(source,'scripts'),file).replaceAll('\\','/');
   scripts[relative]=crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  }
  const identity={sourceCommit:baseline.commit,sourceBranch:baseline.branch,sourceContentSha256:baseline.contentSha256,
   targetCommit:require('node:child_process').execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8',windowsHide:true}).trim(),
   scripts,scriptFingerprint:crypto.createHash('sha256').update(JSON.stringify(Object.entries(scripts).sort())).digest('hex')};
  const prepared={ok:true,identity,engineSources:{mode:'downloaded-snapshots',snapshots:cache.snapshots},source_directory:source,manifest_path:manifestPath,log_path:path.join(source,'prepare.log')};
  fs.writeFileSync(path.join(source,'identity.json'),JSON.stringify(prepared,null,2));
  fs.writeFileSync(path.join(root,'.tmp/outgame-prepare-cached.json'),JSON.stringify(prepared,null,2));
  console.log(JSON.stringify(prepared));
 }finally{await new Promise(resolve=>server.close(resolve));}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
