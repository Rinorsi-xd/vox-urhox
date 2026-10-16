import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
for(const file of ['shared/salvage/items.js','shared/salvage/stash.js','shared/parts/defs.js']){
 const hash=crypto.createHash('sha256').update(fs.readFileSync(path.resolve(root,baseline.snapshot,file))).digest('hex');
 if(hash!==baseline.files[file].sha256)throw Error('Frozen source drift: '+file);
}
const {ITEMS,SELL_RATE}=await import(pathToFileURL(path.resolve(root,baseline.snapshot,'shared/salvage/items.js')));
const {STASH_CELLS,TEST_FILL,stackMax}=await import(pathToFileURL(path.resolve(root,baseline.snapshot,'shared/salvage/stash.js')));
const order={movement:0,weapon:1,function:2,shield:3,structure:4,frame:5,decor:6};
const rules={cells:STASH_CELLS,testFill:TEST_FILL,sellRate:SELL_RATE,
 stack:Object.fromEntries(Object.keys(ITEMS).map(id=>[id,stackMax(id)])),itemOrder:Object.keys(ITEMS),
 marketOrder:Object.values(ITEMS).sort((a,b)=>(order[a.partCat]??0)-(order[b.partCat]??0)||a.name.localeCompare(b.name,'zh')).map(it=>it.id)};
if(process.argv.includes('--write')){
 const file=path.join(root,'assets/UI/Outgame.json'),data=JSON.parse(fs.readFileSync(file));
 const added=Object.keys(ITEMS).filter(id=>!data.items[id]);data.items=ITEMS;
 fs.writeFileSync(file,JSON.stringify(data));
 fs.writeFileSync(path.join(root,'assets/UI/SalvageRules.json'),JSON.stringify(rules));
 process.stdout.write(JSON.stringify({items:Object.keys(ITEMS).length,added}));
}else process.stdout.write(JSON.stringify({items:ITEMS,rules}));
