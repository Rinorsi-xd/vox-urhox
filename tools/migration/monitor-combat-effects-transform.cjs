'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const labels=['setup','bolts','missiles','flares','trails','beams','zaps','rings','flashes','particles','smoke','light','finish'];
function transform(bytes){
 const source=bytes.toString('utf8');assert(!source.includes('VOX_EFFECTS_SECTION_PROBE')&&!source.includes('__voxEffectsScope'));
 const newline=source.includes('\r\n')?'\r\n':'\n',inserted=[];let derived=source;
 const mark=name=>"if _G.VOX_EFFECTS_SECTION_PROBE then _G.VOX_EFFECTS_SECTION_PROBE('mark','fx.section."+name+"') end";
 function before(anchor,line){
  assert.equal(derived.split(anchor).length,2,'Unique exact anchor '+anchor);
  const addition=line+newline;derived=derived.replace(anchor,addition+anchor);inserted.push(addition);
 }
 before('    projectiles=self:Projectiles(projectiles)',"    local __voxEffectsScope <close> = _G.VOX_EFFECTS_SECTION_PROBE and _G.VOX_EFFECTS_SECTION_PROBE('begin','fx.section.setup')");
 before('    for _,proj in ipairs(projectiles) do','    '+mark('bolts'));
 before('    self.missiles:Update(dt,projectiles,Glow)','    '+mark('missiles'));
 for(const name of ['flares','trails','beams','zaps','rings','flashes'])before('    Advance(self.'+name+',dt,','    '+mark(name));
 before('    Particles(self.particles,false);Particles(self.smoke,true)','    '+mark('particles'));
 const inner=mark('smoke')+';';
 derived=derived.replace('Particles(self.particles,false);Particles(self.smoke,true)','Particles(self.particles,false);'+inner+'Particles(self.smoke,true)');inserted.push(inner);
 before('    self.light:Update(dt)','    '+mark('light'));
 before('    for _,batch in pairs(b) do batch:Finish() end','    '+mark('finish'));
 let stripped=derived;
 for(const text of inserted){assert.equal(stripped.split(text).length,2);stripped=stripped.replace(text,'')}
 assert.equal(stripped,source,'Only reversible section timing insertions');
 const result=Buffer.from(derived);
 return {bytes:result,proof:{baselineSha256:sha(bytes),derivedSha256:sha(result),strippedSha256:sha(Buffer.from(stripped)),
  labels:labels.map(x=>'fx.section.'+x),insertions:inserted.length,insertedText:inserted,addedBytes:result.length-bytes.length,
  boundary:'Thirteen whole semantic sections only. Original source recovered byte-for-byte after removing inserted timing statements; no per-particle/vertex/Quad wrappers or gameplay changes.'}};
}
module.exports={transform,labels};
