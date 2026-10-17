'use strict';
const path=require('node:path'),assert=require('node:assert/strict');
const {run}=require('./scope-fx-isolated-run.cjs');
const compact=process.argv[4];assert(['0','1'].includes(compact),'compact 0 or 1 required');
const dpr=Number(process.argv[5]||2);assert([1,2].includes(dpr),'DPR 1 or 2 required');
run(process.argv[2],path.resolve(process.argv[3]),{compact:compact==='1',kinds:['missile'],initialViewport:{width:1280,height:720},dpr})
 .catch(error=>{console.error(error.stack);process.exitCode=1});
