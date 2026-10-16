// Bind a local candidate to current production bytes; no historical report re-signing.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.resolve(root,process.argv[2]);
const prepared=JSON.parse(fs.readFileSync(path.join(source,'identity.json')));
const manifest=JSON.parse(fs.readFileSync(prepared.manifest_path));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const actual={};
for(const file of fs.readdirSync(path.join(root,'scripts'),{recursive:true,withFileTypes:true})) {
 if(!file.isFile()||!file.name.endsWith('.lua'))continue;
 const absolute=path.join(file.parentPath,file.name),relative=path.relative(path.join(root,'scripts'),absolute).replaceAll('\\','/');
 const bytes=fs.readFileSync(absolute),record=manifest.files.find(f=>f.fs_path===relative);
 assert.ok(record,'Missing Lua in package: '+relative);
 const payload=path.join(source,'dist/assets',`${record.uuid}-${record.hash}${record.ext}`);
 assert.ok(bytes.equals(fs.readFileSync(payload)),'Packed Lua differs: '+relative);
 assert.ok(bytes.equals(fs.readFileSync(path.join(source,'scripts',relative))),'Snapshot Lua differs: '+relative);
 actual[relative]=sha(bytes);
}
assert.deepEqual(actual,prepared.identity.scripts,'No missing, extra, or changed production scripts');
const fingerprint=sha(JSON.stringify(Object.entries(actual).sort()));
assert.equal(fingerprint,prepared.identity.scriptFingerprint);
const result={result:'PASS',manifest:path.basename(prepared.manifest_path),sourceCommit:prepared.identity.sourceCommit,
 buildParentCommit:prepared.identity.targetCommit,scriptCount:Object.keys(actual).length,scriptFingerprint:fingerprint,
 scope:'Exact current Lua / snapshot / packaged Lua byte comparison. No engine execution or visual/performance acceptance.'};
fs.writeFileSync(path.join(root,'docs/migration/evidence/perf-1016/package-check.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
