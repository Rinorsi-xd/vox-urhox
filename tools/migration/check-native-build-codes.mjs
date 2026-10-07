import fs from 'node:fs';
import assert from 'node:assert/strict';
import {decodeBlueprint} from 'file:///D:/Rino_Project/Vox/shared/storage.js';
import {Blueprint} from 'file:///D:/Rino_Project/Vox/shared/build/blueprint.js';
const source=JSON.parse(fs.readFileSync('tools/migration/source-build-fixtures.json','utf8')).codes;
const codes=JSON.parse(fs.readFileSync('.tmp/native-build-codes.json','utf8'));
for(let i=0;i<codes.length;i++){
 const decoded=await decodeBlueprint(codes[i]);
 // Missing shellColor and explicit null are equivalent in source blueprint data.
 const native=new Blueprint(),original=new Blueprint();native.load(decoded);original.load(source[i].data);
 assert.deepEqual(native.toJSON(),original.toJSON());
}
console.log(`Original H5 decoded ${codes.length} native exports: PASS`);
