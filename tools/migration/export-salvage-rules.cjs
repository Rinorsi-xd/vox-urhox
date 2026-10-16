// Keep the established entry point on the same SHA-checked frozen source export.
const path=require('node:path');
require('node:child_process').execFileSync(process.execPath,[path.join(__dirname,'workshop-source-items.mjs'),'--write'],{stdio:'inherit'});
