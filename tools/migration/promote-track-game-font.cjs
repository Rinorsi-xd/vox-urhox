// Promote only independently exported original-font sign textures, preserving geometry.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),candidate=path.resolve(root,process.argv[2]||'.tmp/track-original-gamefont-20261015');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const proof=JSON.parse(fs.readFileSync(path.join(candidate,'provenance.json')));
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(proof.sourceCommit,baseline.commit);
assert.ok(proof.inputs.length&&proof.inputs.every(input=>input.baselineMatches&&baseline.files[input.file]?.sha256===input.sha256));
assert.ok(proof.inputs.some(input=>input.file==='shared/fonts/ZCOOLQingKeHuangYou-Regular.woff2'));
const changes=[];
for(const output of proof.outputs){
 const from=path.join(candidate,path.basename(output.file)),to=path.join(root,'assets',output.file),bytes=fs.readFileSync(from);
 assert.equal(hash(bytes),output.sha256,output.file+' candidate mutated');
 const before=fs.readFileSync(to);if(hash(before)===output.sha256)continue;
 assert.match(output.file,/^Track\/texture-(?:[4-9]|[12][0-9]|3[0-6])\.png$/,'Only source typography textures may differ');
 changes.push({file:output.file,from,to,bytes,before,oldSha256:hash(before),sha256:output.sha256});
}
assert.equal(changes.length,33,'Expected the 33 original-font sign/range textures');
const backup=path.join(root,'.tmp/track-gamefont-before-20261015');fs.mkdirSync(backup,{recursive:true});
for(const change of changes){
 const saved=path.join(backup,path.basename(change.file));
 if(fs.existsSync(saved))assert.equal(hash(fs.readFileSync(saved)),change.oldSha256,'Do not overwrite unrelated backup');
 else fs.writeFileSync(saved,change.before);
 fs.writeFileSync(change.to,change.bytes);
 assert.equal(hash(fs.readFileSync(change.to)),change.sha256);
}
const report={result:'PASS',baseline:baseline.commit,candidate,converter:proof.converter,converterSha256:proof.converterSha256,
 policy:'Only original GameFont text textures. Manifest, geometry, layout, materials and all other textures are byte-identical to the candidate.',
 changed:changes.map(({file,oldSha256,sha256,bytes})=>({file,oldSha256,sha256,bytes:bytes.length})),backup};
fs.writeFileSync(path.join(root,'docs/migration/evidence/track-game-font-promotion.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({result:report.result,textures:changes.length,baseline:baseline.commit,backup}));
