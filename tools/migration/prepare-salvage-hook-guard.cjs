'use strict';
// Generates isolated candidates only. Never writes scripts/ or a frozen package.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'candidates/salvage-hook-guard'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function once(s,n,r){assert.equal(s.split(n).length,2,'Unique hook guard integration '+n.slice(0,80));return s.replace(n,r)}
const guard=`---@param mesh StaticModel
function M:InitHookGuard(mesh)
    self.hookMesh=mesh;self.hookMin=mesh.model.boundingBox.min;self.hookMax=mesh.model.boundingBox.max;self.hookHidden=false
end
---@param cameraNode Node
---@param active boolean
function M:GuardCamera(cameraNode,active)
    local mesh=self.hookMesh;if not mesh then return false end
    local hidden=false
    if active and self.nodes.holder.enabled then
        -- Only the top hook: local bounds plus a world-space camera clearance.
        -- Enter at .6 m, leave at .85 m; no physics body or triangle raycasts.
        local p=mesh.node:WorldToLocal(cameraNode.worldPosition);local s=mesh.node.worldScale
        local margin=self.hookHidden and .85 or .6
        local x=margin/math.max(.000001,math.abs(s.x));local y=margin/math.max(.000001,math.abs(s.y));local z=margin/math.max(.000001,math.abs(s.z))
        local a,b=self.hookMin,self.hookMax
        hidden=p.x>=a.x-x and p.x<=b.x+x and p.y>=a.y-y and p.y<=b.y+y and p.z>=a.z-z and p.z<=b.z+z
    end
    if hidden~=self.hookHidden then mesh:SetEnabled(not hidden);self.hookHidden=hidden end
    return hidden
end
`;
const sources={};for(const name of ['render/SalvageCinematics.lua','salvage/Cinematics.lua'])sources[name]=fs.readFileSync(path.join(root,'scripts',name),'utf8');
let render=sources['render/SalvageCinematics.lua'];
render=once(render,"mesh.castShadows=d.shadow\n", "mesh.castShadows=d.shadow\n        if d.motion=='frame' and d.model=='SalvageCine/model-15.bin' then self:InitHookGuard(mesh) end\n");
render=once(render,'function M:HideShip()',guard+'function M:HideShip()');
render=once(render,'frameVisible=self.nodes.holder.enabled,batches=', 'frameVisible=self.nodes.holder.enabled,hookVisible=self.hookMesh and self.hookMesh.enabled,hookGuarded=self.hookHidden==true,batches=');
render=once(render,'self.materials={};self.nodes={};self.root=nil','self.materials={};self.nodes={};self.root=nil;self.hookMesh=nil');
let cine=sources['salvage/Cinematics.lua'];
cine=once(cine,'function M:Camera()\n    if not self.playing then return end', 'function M:Camera()\n    self.view:GuardCamera(self.session.camera:GetNode(),not self.playing)\n    if not self.playing then return end');
const result={kind:'ISOLATED_CANDIDATE_NOT_MERGED',files:{},boundary:'Only near-camera frame/model-15 StaticModel is masked; holder/ship/doors, physics and cinematic timing unchanged. Bounds and component cached once, one WorldToLocal per active camera update, .6/.85m hysteresis, no scene/mesh raycasts. Native rendering pending.'};
for(const [name,bytes]of [['render/SalvageCinematics.lua',render],['salvage/Cinematics.lua',cine]]){const file=path.join(out,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);result.files[name]={originalSha256:sha(sources[name]),candidateSha256:sha(bytes),path:path.relative(root,file)}}
fs.writeFileSync(path.join(out,'identity.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
