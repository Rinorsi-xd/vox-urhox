'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),zlib=require('node:zlib');
const resources={gameplay:'Salvage/Gameplay.json',runData:'Salvage/RunData.json',workshop:'UI/Workshop.json',catalogue:'UI/Outgame.json'};
function loadFrozenReference(identity,read=fs.readFileSync){
 assert.ok(identity?.ok&&identity.qa,'Actual QA frozen identity required');
 assert.ok(path.isAbsolute(identity.source_directory||''),'Frozen source path required');
 const root=path.resolve(identity.source_directory),relative=path.relative(root,identity.manifest_path||'');
 assert.ok(relative&&!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative),'Manifest stays in frozen package');
 const manifestBytes=read(identity.manifest_path),manifest=JSON.parse(manifestBytes.toString('utf8'));
 assert.equal(manifest.assets_pak,0,'Loose resource package required');
 const values={},audit={manifest:path.basename(identity.manifest_path),manifestSha256:crypto.createHash('sha256').update(manifestBytes).digest('hex'),resources:{}};
 for(const [key,name]of Object.entries(resources)){
  const rows=manifest.files.filter(row=>row.fs_path===name);assert.equal(rows.length,1,'Unique frozen resource '+name);const row=rows[0];
  assert.ok(!row.source&&/^[A-Za-z0-9_-]+$/.test(row.uuid)&&/^[0-9a-f]{8}$/.test(row.hash)&&row.ext==='.json','Local JSON payload '+name);
  const payload=read(path.join(root,'dist/assets',row.uuid+'-'+row.hash+row.ext));
  assert.equal(payload.length,row.size,'Frozen size '+name);
  assert.equal(zlib.crc32(payload).toString(16).padStart(8,'0'),row.hash,'Frozen CRC '+name);
  values[key]=JSON.parse(payload.toString('utf8'));
  audit.resources[name]={bytes:payload.length,crc32:row.hash,sha256:crypto.createHash('sha256').update(payload).digest('hex')};
 }
 return {...values,audit};
}
module.exports={loadFrozenReference,resources};
