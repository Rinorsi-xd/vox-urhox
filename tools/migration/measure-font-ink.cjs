// Measure existing same-size screenshots only. This does not change typography.
const fs=require('node:fs'),path=require('node:path');
const sharp=require('C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'docs/migration/evidence/source-font-pages-2026-10-15T08-28-33-064Z/settings.png');
const target=path.join(root,'docs/migration/evidence/target-font-pages-manifest-2729bc84-2026-10-15T08-34-29-029Z/pc-settings.png');
async function ink(file,rect){
 const {data,info}=await sharp(file).extract(rect).removeAlpha().raw().toBuffer({resolveWithObject:true});
 let x0=info.width,y0=info.height,x1=-1,y1=-1,bright=0,edge=0,colorEdge=0;
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
  const p=(y*info.width+x)*info.channels,r=data[p],g=data[p+1],b=data[p+2];
  if(r>140&&g>150&&b>170){bright++;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}
  // Foreground AA edge relative to known source/target title color #e4f3ff
  // and background #193e6e. Separate coverage-channel spread from brightness.
  const ar=(r-25)/(228-25),ag=(g-62)/(243-62),ab=(b-110)/(255-110),a=(ar+ag+ab)/3;
  if(a>.15&&a<.85){edge++;if(Math.max(ar,ag,ab)-Math.min(ar,ag,ab)>.15)colorEdge++;}
 }
 return {brightPixels:bright,brightBounds:x1<0?null:[rect.left+x0,rect.top+y0,x1-x0+1,y1-y0+1],edgePixels:edge,channelCoverageSpreadPixels:colorEdge};
}
(async()=>{
 const result={source,target,method:'Same pixel viewport; known foreground/background threshold, no rescaling. Coverage spread is an AA diagnostic, not proof of the engine rasterizer implementation.',samples:[]};
 for(const [label,rect] of [['title',{left:820,top:330,width:100,height:35}],['subtitle',{left:820,top:362,width:120,height:22}]]){
  result.samples.push({label,rect,source:await ink(source,rect),target:await ink(target,rect)});
  await sharp(source).extract(rect).resize(rect.width*5,rect.height*5,{kernel:'nearest'}).toFile(path.join(root,'docs/migration/evidence/font-ink-'+label+'-source.png'));
  await sharp(target).extract(rect).resize(rect.width*5,rect.height*5,{kernel:'nearest'}).toFile(path.join(root,'docs/migration/evidence/font-ink-'+label+'-target.png'));
 }
 fs.writeFileSync(path.join(root,'docs/migration/evidence/font-ink-settings.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
