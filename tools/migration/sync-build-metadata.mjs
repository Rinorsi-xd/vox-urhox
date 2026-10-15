// Small rule metadata only; source is read-only and no render models are loaded.
import fs from 'node:fs';
import {LEG_GLB} from 'file:///D:/Rino_Project/Vox/shared/parts/legData.js';
import {RETIRED_WHEELS,BLOCK_MATS} from 'file:///D:/Rino_Project/Vox/shared/parts/defs.js';
fs.writeFileSync(new URL('../../assets/Parts/BuildRules.json',import.meta.url),JSON.stringify({
 retiredWheels:[...RETIRED_WHEELS],blockMaterials:BLOCK_MATS,legStances:Object.fromEntries(Object.entries(LEG_GLB).map(([k,v])=>[k,v.stanceCells]))
}));
console.log('Updated legacy wheel IDs and authored standing-leg cells');
