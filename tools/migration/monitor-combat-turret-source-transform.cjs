'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function transform(bytes){
 const source=bytes.toString('utf8');assert(!source.includes('__voxObserved')&&!source.includes('VOX_TURRET_SOURCE_PROBE'));
 const anchors=[
  ["local function Prepare(parts,part,owner,checkpoint)","'prepare'"],
  ["local function Evaluate(context,checkpoint)","'evaluate'"],
  ["function M.For(bp,owner,checkpoint)","'for',bp,cached[bp]~=nil"],
 ];
 let derived=source;const inserted=[];
 for(const [anchor,args]of anchors){
  const expression=new RegExp(anchor.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(\\r?\\n)','g');
  const matches=[...derived.matchAll(expression)];assert.equal(matches.length,1,'Exact entry anchor '+anchor);
  const newline=matches[0][1],line="    local __voxObserved <close> = _G.VOX_TURRET_SOURCE_PROBE and _G.VOX_TURRET_SOURCE_PROBE("+args+")"+newline;
  derived=derived.replace(expression,match=>match+line);inserted.push(line);
 }
 let stripped=derived;for(const line of inserted){assert.equal(stripped.split(line).length,2);stripped=stripped.replace(line,'')}
 assert.equal(stripped,source,'Only three reversible entry lines may change');
 const result=Buffer.from(derived);return {bytes:result,proof:{method:'three-reversible-entry-lines',baselineSha256:sha(bytes),derivedSha256:sha(result),
  strippedSha256:sha(Buffer.from(stripped)),insertedLines:inserted.map(x=>x.replace(/\r?\n$/,'')),addedBytes:result.length-bytes.length}};
}
module.exports={transform};
