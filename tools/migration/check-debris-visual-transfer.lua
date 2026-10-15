-- Actual render modules with observed node/resource adapters, no native timing.
local checks={}
local function Check(value,label) assert(value,label);checks[#checks+1]=label end
local function Point(x,y,z) return {x=x,y=y,z=z} end
Vector3={ZERO=Point(0,0,0)}
cjson={null={}}
local created,disposed,builds,releases=0,0,0,0
local function Node(parent,name)
    created=created+1
    local n={parent=parent,name=name,children={},enabled=true}
    if parent then parent.children[n]=true end
    function n:CreateChild(label) return Node(self,label) end
    function n:SetScale(scale) self.scale=scale end
    function n:SetParent(p) self.parent.children[self]=nil;self.parent=p;p.children[self]=true end
    function n:Dispose()
        Check(not self.disposed,'node disposed once '..self.name)
        local list={};for child in pairs(self.children) do list[#list+1]=child end
        for _,child in ipairs(list) do child:Dispose() end
        if self.parent then self.parent.children[self]=nil end
        self.disposed=true;disposed=disposed+1
    end
    return n
end
local defs={block={shape='cube',instanced=true},complex={shape='cube',instanced=true},other={instanced=false}}
package.loaded.Config={CELL=.5,HexLinear=function(color,var)return {color=color,var=var}end}
package.loaded['parts.Defs']={PARTS=defs}
package.loaded['core.Coord']={CellPos=Point,Vec=Point,RotQuat=function(rot)return {rot=rot}end}
package.loaded['parts.PartAssets']={Get=function(kind)return {whole={},segments=kind=='complex' and {} or cjson.null}end,
    Release=function(resources) releases=releases+#resources end}
package.loaded['render.JoinedSurface']={IsJoined=function(p)return p.g==1 end}
package.loaded['render.JoinedMesh']={New=function(root)
    return {meshes={},Add=function()end,Remove=function()end,Repaint=function()end,Update=function()end,Clear=function()end,Dispose=function()end}
end}
package.loaded['render.LiveryLayer']={New=function()
    return {PartsChanged=function()end,Clear=function()end,Dispose=function()end}
end}
package.loaded['render.PartRig']={Build=function(node,data,part,vis)
    builds=builds+1;vis.data=data;vis.rig={};vis.shellSlots={};vis.materialSlots={}
    vis.models={{identity=builds}};vis.resources={'model'}
end}
package.loaded['render.WeaponView']={}
local View=require 'render.VehicleView'
package.loaded['render.DriveView']={}
local Combat=require 'render.CombatView'
local scene=Node(nil,'Scene')
local combat=Combat.New(scene)
local function Part(id,kind,g) return {id=id,type=kind or 'block',pos={id,2,3},rot=10,color=123,_cells={{id,2,3}},g=g or 0} end
local function Driver(parts)
    local driver={view=View.New(scene,'Drive')}
    for _,p in ipairs(parts) do driver.view:AddPart(p) end
    function driver:Dispose() if not self.disposed then self.disposed=true;self.view:Dispose() end end
    return driver
end
local a,b,c=Part(1),Part(2,'complex'),Part(3,'block',1)
local donor=Driver({a,b,c})
local unit={};combat.units[unit]=donor
local collision=Part(1);local other=Driver({collision});local otherUnit={};combat.units[otherUnit]=other
local original=donor.view.visuals[1];local model=original.models[1]
original.node.position=Point(50,50,50);original.node.rotation={rot=99}
local piece={parts={a,b,c}}
local beforeBuilds=builds
combat:Consume({viewEvents={{type='unitKilled',unit=unit}},debris={events={{type='spawn',piece=piece}}}})
local target=combat.pieces[piece].view
Check(combat.lastTransferred==1,'only exact eligible static visual transferred')
Check(target.visuals[1]==original and target.visuals[1].models[1]==model,'same visual/model ownership retained')
Check(target.visuals[1].node.parent==target.root and not target.visuals[1].node.disposed,'target owns live node')
Check(target.visuals[1].node.position.x==a.pos[1] and target.visuals[1].node.rotation.rot==10,'authored pose restored before piece pose')
Check(target.visuals[1].node.scale==1 and target.visuals[1].node.enabled,'neutral static transform/visibility')
Check(other.view.visuals[1].part==collision and not other.disposed,'same numeric ID on another car untouched')
Check(builds-beforeBuilds==1,'complex rig reconstructed and joined branch retained')
Check(donor.disposed and releases==1,'donor releases complex resource exactly once, retains moved resource')
Check(target.visuals[2].part==b and target.visuals[3].part==c,'all piece parts available in same consume')
combat:Consume({viewEvents={},debris={events={{type='remove',piece=piece}}}})
Check(not combat.pieces[piece] and original.node.disposed,'piece removal retires moved node')
combat:Dispose();scene:Dispose()
Check(releases==builds,'every acquired model ownership released once')
Check(created==disposed,'no node leak after normal cleanup')
-- A loader cancellation may throw at an event checkpoint after preparation.
scene=Node(nil,'CancelScene');combat=Combat.New(scene)
local p=Part(1);unit={};donor=Driver({p});combat.units[unit]=donor;piece={parts={p}}
local ok=pcall(function()
    combat:Consume({viewEvents={{type='unitKilled',unit=unit}},debris={events={{type='spawn',piece=piece}}}},function()error('cancel')end)
end)
Check(not ok and combat.pieces[piece]~=nil,'prepared piece retained before cancellation checkpoint')
combat:Dispose();scene:Dispose()
Check(created==disposed and releases==builds,'cancellation frees every node/model ownership once')
return checks
