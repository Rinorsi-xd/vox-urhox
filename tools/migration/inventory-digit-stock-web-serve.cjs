'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),Module=require('node:module'),crypto=require('node:crypto');
const identity=process.argv[2],port=Number(process.argv[3]);
assert(identity&&Number.isInteger(port)&&port>=1024&&port<=65535);
assert.equal(process.argv.length,4,'Usage: node inventory-digit-stock-web-serve.cjs identity.json port');
const sourceFile=path.join(__dirname,'serve-outgame.cjs'),original=fs.readFileSync(sourceFile,'utf8');
const marker='const fullProbe=probe+aimEngineProbe+salvageStockProbe;';assert.equal(original.split(marker).length,2);
const suffix=fs.readFileSync(path.join(__dirname,'inventory-digit-stock-observer.lua'),'utf8');
const sha=crypto.createHash('sha256').update(suffix).digest('hex');
const code=original.replace(marker,marker.slice(0,-1)+'+'+JSON.stringify('\n'+suffix)+';')
 .replace('probeSha256,port,processId:','probeSha256,inventoryDigitObserver:true,inventoryDigitObserverSha256:'+JSON.stringify(sha)+',port,processId:');
process.env.VOX_PREPARE_FILE=path.resolve(identity);process.env.VOX_PREVIEW_PORT=String(port);process.argv.push('--qa');
const implementation=new Module(sourceFile,module);implementation.filename=sourceFile;implementation.paths=module.paths;
implementation._compile(code,sourceFile);implementation.exports.startPreviewServer();
