'use strict';
const path=require('node:path');
const {run,selfTest}=require('./scope-fx-isolated-run.cjs');
if(process.argv.includes('--self-test'))selfTest();
else run(process.argv[2],path.resolve(process.argv[3]),{equipmentEmit:true,resizeMissile:true}).catch(e=>{console.error(e.stack);process.exitCode=1});
