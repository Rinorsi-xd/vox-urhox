// Freeze only migration inputs. Verify originals again after copying because
// the H5 checkout may be edited while this process runs.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const source='D:/Rino_Project/Vox',target=path.resolve(__dirname,'../..');
const stamp=new Date().toISOString().replace(/[:.]/g,'-');
const destination=path.join(target,'.tmp','outgame-source-'+stamp);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const files={};
function copy(relative){
 const from=path.join(source,relative);
 if(fs.statSync(from).isDirectory()){for(const name of fs.readdirSync(from))copy(path.join(relative,name));return;}
 const bytes=fs.readFileSync(from),to=path.join(destination,relative);
 fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,bytes);
 files[relative.replaceAll('\\','/')]={sha256:hash(bytes),bytes:bytes.length};
}
for(const entry of ['shared','three/src','three/vendor','three/index.html'])copy(entry);
for(const [name,record]of Object.entries(files))if(hash(fs.readFileSync(path.join(source,name)))!==record.sha256)throw Error('Source changed while freezing: '+name);
const git=(...args)=>cp.execFileSync('git',args,{cwd:source,encoding:'utf8'}).trim();
const manifest={schema:1,source,branch:git('branch','--show-current'),commit:git('rev-parse','HEAD'),subject:git('log','-1','--format=%s'),
 frozenAt:new Date().toISOString(),snapshot:destination,workingTree:git('status','--porcelain=v1'),
 scope:['garage','builder','inventory','weapons and model presentation','creative workshop'],excluded:['tutorial','combat simulation','endless mode'],files};
manifest.contentSha256=hash(Buffer.from(JSON.stringify(files)));
fs.mkdirSync(path.join(target,'docs/migration'),{recursive:true});
fs.writeFileSync(path.join(target,'docs/migration/outgame-baseline.json'),JSON.stringify(manifest,null,2));
console.log(JSON.stringify({snapshot:destination,branch:manifest.branch,commit:manifest.commit,contentSha256:manifest.contentSha256,files:Object.keys(files).length,bytes:Object.values(files).reduce((s,v)=>s+v.bytes,0)},null,2));
