const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'docs/migration/outgame-baseline.json')));
const sourcePath = path.join(baseline.snapshot, 'shared/ui/inventory.js');
const source = fs.readFileSync(sourcePath, 'utf8');
const sha = crypto.createHash('sha256').update(source).digest('hex');
if (sha !== baseline.files['shared/ui/inventory.js'].sha256) throw Error('Frozen inventory source drift');
const detail = source.replace(/\r\n/g,'\n').match(/\t_detail\( type \) \{([\s\S]*?)\n\t\}\n\n\t\/\/.*\n\trenderHotbar/);
if (!detail) throw Error('Frozen full _detail method not found');
const catalog = JSON.parse(execFileSync(process.execPath, [path.join(__dirname, 'source-inventory-detail-golden.cjs')], {encoding:'utf8'}));
if (catalog.resourceDrift.length) throw Error('Current resource stats differ from frozen source');
const parts = Object.fromEntries(catalog.cases.map(c => [c.id, c.def]));
const stats = Object.fromEntries(catalog.cases.map(c => [c.id, c.ws]));
const context = vm.createContext({PARTS:parts, CAT_ICON:{}, CAT_NAME:{}, MAX:{budget:1,mass:1,hp:1},
 icon:()=>'', weaponStats:id=>stats[id], weaponDps:s=>s.rate?s.damage*s.rate:s.damage/s.interval});
vm.runInContext(`globalThis.detail = function(type) {${detail[1]}\n};`, context);
const cases=[];
for (const expanded of [false,true]) for (const offset of [0,73,287]) {
 const aside={scrollTop:offset,innerHTML:'',querySelector:()=>({addEventListener(){}})};
 const owner={detail:aside,hotbar:[],thumbs:{},shown:null,detailExpanded:expanded};
 for (const id of ['tianyuanDrill','fuyuanDrill','laser1']) {
  context.detail.call(owner,id);
  if (aside.scrollTop!==offset || owner.shown!==id || !aside.innerHTML.includes(parts[id].name)) throw Error('Unexpected source consumer state');
  cases.push({expanded,offset,id,shown:owner.shown,scrollTop:aside.scrollTop});
 }
}
process.stdout.write(JSON.stringify({baseline:baseline.commit,sourceSha256:sha,cases,
 boundary:'Executes the complete frozen H5 _detail method with DOM sinks; DOM layout/clamping is not emulated. Existing actual Web evidence separately records retained offsets. No browser or performance claim.'}));
