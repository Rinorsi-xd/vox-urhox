'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const identity=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
assert(identity.monitorCombat?.isolated&&identity.monitorCombat.monitorEnabled&&identity.monitorCombat.controlledPlacement);
require('./g1-web-cpu-serve.cjs');
