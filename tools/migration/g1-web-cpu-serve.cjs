'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const identity=process.argv[2],port=Number(process.argv[3]);assert(identity&&port>=1024&&port<=65535,'identity.json port required');
assert.equal(process.argv.length,4,'No normal QA/gameplay flags accepted');
const prepared=JSON.parse(fs.readFileSync(identity,'utf8'));assert(prepared.ok&&prepared.g1WebCpu?.isolated);
process.env.VOX_PREPARE_FILE=path.resolve(identity);process.env.VOX_PREVIEW_PORT=String(port);
const server=require('./serve-outgame.cjs').startPreviewServer();
const handlers=server.listeners('request');server.removeAllListeners('request');
server.on('request',(request,response)=>{
 if(request.url.split('?')[0]==='/favicon.ico'){
  console.log(JSON.stringify({request:request.url,status:204,boundary:'Empty browser tab icon only'}));
  response.writeHead(204);response.end();return;
 }
 for(const handler of handlers)handler.call(server,request,response);
});
