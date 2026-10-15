import fs from 'node:fs';
import assert from 'node:assert/strict';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const load=name=>import(pathToFileURL(path.resolve(baseline.snapshot,name)));
const {decodeBlueprint}=await load('shared/storage.js');
const {Blueprint}=await load('shared/build/blueprint.js');
const source=JSON.parse(fs.readFileSync('tools/migration/source-build-fixtures.json','utf8')).codes;
const codes=JSON.parse(fs.readFileSync('.tmp/native-build-codes.json','utf8'));
for(let i=0;i<codes.length;i++){
 const decoded=await decodeBlueprint(codes[i]);
 // Missing shellColor and explicit null are equivalent in source blueprint data.
 const native=new Blueprint(),original=new Blueprint();native.load(decoded);original.load(source[i].data);
 assert.deepEqual(native.toJSON(),original.toJSON());
}
console.log(`Original H5 decoded ${codes.length} native exports: PASS`);
