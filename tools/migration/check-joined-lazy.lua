-- Exercise the actual before/after module with identical engine adapters.
local checks=0
local function Check(ok,message) assert(ok,message);checks=checks+1 end
local function Case(path,lazy)
    local edges=0
    local Surface={Build=function(parts)
        local positions={};for _,p in ipairs(parts) do positions[#positions+1]=p.id end
        return {},#positions>0 and {[1]=positions} or {}
    end,Edges=function(pos) edges=edges+1;local out={};for _,id in ipairs(pos) do out[#out+1]={id,0,0} end;return out end}
    local function Node()
        local n={enabled=true,children={}}
        function n:CreateChild() local c=Node();self.children[#self.children+1]=c;return c end
        function n:Dispose() self.disposed=true end
        function n:CreateComponent()
            local g={}
            function g:BeginGeometry() self.vertices={} end
            function g:DefineVertex(v) self.vertices[#self.vertices+1]=v end
            function g:DefineColor() end
            function g:Commit() end
            function g:SetMaterial() end
            return g
        end
        return n
    end
    local modules={['render.JoinedSurface']=Surface,['parts.Materials']={Joined=function() end,JoinedOutline=function() end},
        ['core.Coord']={Vec=function(...) return {...} end},Config={HexLinear=function(c) return c end}}
    local env=setmetatable({require=function(k) return assert(modules[k],k) end},{__index=_G})
    local M=assert(loadfile(path,'t',env))()
    local m=M.New(Node());m:Add({id=1});m:Update()
    Check(edges==(lazy and 0 or 1),'initial edge generation')
    m:SetXray(true);Check(edges==1,'first xray constructs edges')
    Check(m.outlines[1].node.enabled,'xray visible')
    Check(m.outlines[1].geometry.vertices[1][1]==1,'source edge positions')
    m:SetXray(false);m:Add({id=2});m:Update()
    Check(edges==(lazy and 1 or 2),'hidden rebuild defers edges')
    m:SetXray(true);Check(edges==2 and #m.outlines[1].geometry.vertices==2,'updated xray')
    m:SetXray(false);m:Remove(1);m:Remove(2);m:Update();m:SetXray(true)
    Check(next(m.outlines)==nil,'removed groups retired')
    m:Clear();Check(next(m.parts)==nil and next(m.outlines)==nil,'clear ownership')
    m:Dispose();Check(m.root.disposed,'dispose root')
end
Case('.tmp/outgame-cached-1792063134142/scripts/render/JoinedMesh.lua',false)
Case('scripts/render/JoinedMesh.lua',true)
return {result='PASS',checks=checks}
