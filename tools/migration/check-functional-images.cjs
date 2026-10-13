const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../../docs/migration/evidence');
(async()=>{
 const evidence=[];
 for(const family of ['story','missiles'])for(const device of ['pc','phone-landscape','tablet']){
  const names=family==='story'?['live','install-3','pirates','result']:['lock-0','volley-0','reload-0'];
  for(const state of names){
   const name=`${family}-web-${device}-${state}.png`,file=path.join(root,name);
   const image=sharp(file),meta=await image.metadata(),stats=await image.stats();
   const center=await sharp(file).extract({left:Math.floor(meta.width*.3),top:Math.floor(meta.height*.3),width:Math.floor(meta.width*.4),height:Math.floor(meta.height*.4)}).stats();
   const rgb=stats.channels.slice(0,3).map(c=>c.stdev),centralRgb=center.channels.slice(0,3).map(c=>c.stdev);
   assert.ok(rgb.some(v=>v>15),name+' is nonblank');assert.ok(centralRgb.some(v=>v>8),name+' has central rendered pixels');
   evidence.push({file:name,width:meta.width,height:meta.height,rgbStdev:rgb,centerStdev:centralRgb});
  }
 }
 fs.writeFileSync(path.join(root,'functional-image-pixels.json'),JSON.stringify({result:'PASS',scope:'Screenshot RGB and central-pixel variation; not a parity or device FPS measurement.',images:evidence},null,2));
 console.log(JSON.stringify({result:'PASS',images:evidence.length}));
})().catch(e=>{console.error(e);process.exitCode=1;});
