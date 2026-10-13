-- Whole authored models, bounded detailed preview pool, one shared cell-line
-- buffer and one subcell face. Nothing here participates in picking/collision.
local Config=require 'Config'
local Coord=require 'core.Coord'
local Assets=require 'parts.PartAssets'
local Quality=require 'render.Quality'
local M={};M.__index=M
local COLORS={ok=0x3fe6ff,bad=0xff3b3b,paint=0xffd23f,erase=0xff5a3b,selected=0xffc21a}
local EDGES={{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}}
local function NewMaterial(shader)
    local m=Material:new();assert(m:SetSurfaceShader('Shaders/BLGL/'..shader..'.shader'));return m
end
function M.New(parent)
    local self=setmetatable({pool={},limit=Quality.current.name=='mobile' and 16 or 48,maxCells=4096,gate=require('app.ResourceGate').New()},M)
    self.root=parent:CreateChild('BuildPreview');self.root:SetScale(Config.CELL)
    self.lines=self.root:CreateChild('Cells'):CreateComponent('CustomGeometry')
    self.lineMaterial=NewMaterial('BuildLines');self.lines:SetMaterial(self.lineMaterial)
    self.face=self.root:CreateChild('HitFace'):CreateComponent('CustomGeometry')
    self.faceMaterial=NewMaterial('BuildFace');self.face:SetMaterial(self.faceMaterial)
    self.volume=self.root:CreateChild('StretchVolume'):CreateComponent('CustomGeometry')
    self.volumeMaterial=NewMaterial('BuildGhost');self.volume:SetMaterial(self.volumeMaterial)
    return self
end
function M:Warm(editor,retry,selectionParts)
    local parts={};local pv=editor.preview
    if pv and pv.paste then parts=pv.paste
    elseif pv then
        parts[1]={type=pv.type,rot=pv.rot}
        if pv.mirror then parts[2]={type=pv.type,rot=pv.mirror.rot} end
    elseif not editor.emptySlot then parts[1]={type=editor.type,rot=editor.sampledRot or require('core.Rotations').IDENTITY} end
    -- Detailed drawing is bounded, but confirmation can add every source item.
    -- Warm all distinct type/orientation resources so omitted preview models
    -- cannot become missing resources when the complete batch is committed.
    if selectionParts then
        parts={};local seen={}
        for _,part in ipairs(selectionParts) do local key=Assets.Key(part.type,part.rot)
            if not seen[key] then parts[#parts+1]=part;seen[key]=true end
        end
    end
    local paths=require('parts.Dependencies').For(parts);local key=table.concat(paths,'|')
    if self.warmKey~=key or retry and self.gate.state=='failed' then
        self.warmKey=key;self.ready=false;self.signature=nil
        self.gate:Start(paths,function(ok)
            self.ready=ok;self.signature=nil;editor.dirty=true
        end)
    elseif self.gate.state=='failed' then
        self.ready=false
    end
    return self.ready
end
function M:Drop(item)
    item.node:Dispose();item.models={};Assets.Release(item.resources);item.material:Dispose()
end
function M:Model(index,it,state)
    if index>self.limit or not self.ready then return end
    local key=Assets.Key(it.type,it.rot);local item=self.pool[index]
    if item and item.key~=key then self:Drop(item);item=nil end
    if not item then
        item={key=key,node=self.root:CreateChild('Ghost'..index),models={},resources={},material=NewMaterial('BuildGhost')}
        for _,layer in ipairs(Assets.Get(it.type,it.rot).whole.layers) do
            local beam=true;for _,slot in ipairs(layer.slots) do if slot:sub(1,4)~='beam' then beam=false end end
            if not beam then
                local sm=item.node:CreateComponent('StaticModel');sm.model=assert(cache:GetResource('Model',layer.model))
                for i=1,#layer.slots do sm:SetMaterial(i-1,item.material) end
                item.models[#item.models+1]=sm;item.resources[#item.resources+1]=layer.model
            end
        end
        self.pool[index]=item
    end
    item.node.position=Coord.CellPos(it.pos[1],it.pos[2]+.5,it.pos[3]);item.node.rotation=Coord.RotQuat(it.rot)
    item.material:SetShaderParameter('tint_color',Variant(Config.HexLinear(COLORS[state],state=='bad' and .3 or .4)))
end
function M:Cell(c,color)
    if self.cellCount>=self.maxCells then return end;self.cellCount=self.cellCount+1
    local vertices={}
    for i=0,7 do vertices[i+1]=Coord.CellPos(c[1]+((i&1)~=0 and .5 or -.5),c[2]+((i&2)~=0 and 1 or 0),c[3]+((i&4)~=0 and .5 or -.5)) end
    for _,edge in ipairs(EDGES) do for _,v in ipairs(edge) do self.lines:DefineVertex(vertices[v]);self.lines:DefineColor(color) end end
end
function M:Region(lo,hi,state,fill)
    local color=Config.HexLinear(COLORS[state or 'ok'],.85);local vertices={}
    for i=0,7 do
        vertices[i+1]=Coord.CellPos((i&1)~=0 and hi[1]+.5 or lo[1]-.5,(i&2)~=0 and hi[2]+1 or lo[2],(i&4)~=0 and hi[3]+.5 or lo[3]-.5)
    end
    for _,edge in ipairs(EDGES) do for _,v in ipairs(edge) do self.lines:DefineVertex(vertices[v]);self.lines:DefineColor(color) end end
    if fill then
        local faces={{{1,2,6,5},{0,-1,0}},{{3,7,8,4},{0,1,0}},{{1,5,7,3},{-1,0,0}},{{2,4,8,6},{1,0,0}},{{1,3,4,2},{0,0,-1}},{{5,6,8,7},{0,0,1}}}
        for _,face in ipairs(faces) do for _,index in ipairs({1,3,2,1,4,3}) do
            self.volume:DefineVertex(vertices[face[1][index]]);self.volume:DefineNormal(Coord.Vec(table.unpack(face[2])))
        end end
    end
end
function M:Face(hit,state)
    self.face:BeginGeometry(0,TRIANGLE_LIST)
    if hit and hit.cell then
        local h=hit.sub and .125 or .5;local c,n={},hit.normal
        for a=1,3 do c[a]=hit.cell[a]+(a==2 and .5 or 0)+(hit.sub and ((hit.sub[a]+.5)/4-.5) or 0)+n[a]*(h+.005) end
        local u=n[1]~=0 and {0,0,1} or {1,0,0};local v=n[2]~=0 and {0,0,1} or {0,1,0}
        for _,uv in ipairs({{0,0},{1,0},{1,1},{0,0},{1,1},{0,1}}) do
            self.face:DefineVertex(Coord.CellPos(c[1]+(uv[1]*2-1)*h*u[1]+(uv[2]*2-1)*h*v[1],c[2]+(uv[1]*2-1)*h*u[2]+(uv[2]*2-1)*h*v[2],c[3]+(uv[1]*2-1)*h*u[3]+(uv[2]*2-1)*h*v[3]))
            self.face:DefineTexCoord(Vector2(uv[1],uv[2]))
        end
        self.faceMaterial:SetShaderParameter('tint_color',Variant(Config.HexLinear(COLORS[state])))
    end
    self.face:Commit()
end
function M:Refresh(editor,showHit,selecting,drag)
    local selectionParts
    if selecting then
        selectionParts={}
        if showHit then
            if drag then if #drag.parts<=400 then selectionParts=drag.parts end
            else local hit=editor.hit;local p=hit and editor.bp.parts[hit.partId];if p then selectionParts={p} end end
        end
    end
    local stretchParts=editor.stretch and editor.stretch.phase=='selection' and editor.stretch.items
    self:Warm(editor,false,stretchParts or selectionParts)
    if not self.ready then
        for _,item in ipairs(self.pool) do self:Drop(item) end;self.pool={}
    end
    local stretch=showHit and editor.stretch
    local pv=showHit and not selecting and not stretch and editor.preview;local count=0
    local key={editor.history.revision,editor.tool,tostring(selecting)}
    if stretch then key[#key+1]='stretch'..stretch.phase..':'..stretch.key end
    if drag and drag.lo then key[#key+1]=table.concat(drag.lo,',');key[#key+1]=table.concat(drag.hi,',') end
    for _,p in ipairs(selectionParts or {}) do key[#key+1]='h'..p.id end
    local function Stamp(it)
        key[#key+1]=it.type;key[#key+1]=table.concat(it.pos,',');key[#key+1]=it.rot;key[#key+1]=it.res.ok and 1 or 0
    end
    if pv then
        if pv.paste then for _,it in ipairs(pv.paste) do Stamp(it) end
        else Stamp(pv);if pv.mirror then Stamp({type=pv.type,pos=pv.mirror.pos,rot=pv.mirror.rot,res=pv.mirror.res}) end end
    end
    for _,p in ipairs(editor:Selected()) do key[#key+1]='s'..p.id end
    local hit=showHit and editor.hit
    if hit then key[#key+1]=table.concat(hit.cell,',');key[#key+1]=table.concat(hit.normal,',');key[#key+1]=hit.sub and table.concat(hit.sub,',') or '' end
    local signature=table.concat(key,'|')
    if self.signature==signature then return end;self.signature=signature
    self.cellCount=0
    self.lines:BeginGeometry(0,LINE_LIST)
    self.volume:BeginGeometry(0,TRIANGLE_LIST)
    local function Item(it,state)
        count=count+1;self:Model(count,it,state)
        local color=Config.HexLinear(COLORS[state],.65)
        for _,c in ipairs(it.res.cells) do self:Cell(c,color) end
    end
    if stretch then
        local state=stretch.bad and 'bad' or 'ok'
        self.volumeMaterial:SetShaderParameter('tint_color',Variant(Config.HexLinear(COLORS[state],.2)))
        if stretch.phase=='selection' then
            for i,it in ipairs(stretch.items) do
                if i<=self.limit then Item({type=it.type,pos=it.pos,rot=it.rot,res={cells={it.pos}}},state)
                else self:Cell(it.pos,Config.HexLinear(COLORS[state],.65)) end
            end
        else
            self:Region(stretch.lo,stretch.hi,state,true)
            if #stretch.mirrorCells>0 then self:Region({-stretch.hi[1],stretch.lo[2],stretch.lo[3]},{-stretch.lo[1],stretch.hi[2],stretch.hi[3]},state,true) end
            if stretch.type~='cube' then for i=1,math.min(#stretch.cells,self.limit,96) do
                local c=stretch.cells[i];count=count+1;self:Model(count,{type=stretch.type,pos=c,rot=stretch.rot},state)
            end end
        end
    elseif pv then
        if pv.paste then for _,it in ipairs(pv.paste) do Item(it,it.res.ok and 'ok' or 'bad') end
        else
            Item(pv,pv.res.ok and 'ok' or 'bad')
            if pv.mirror then Item({type=pv.type,pos=pv.mirror.pos,rot=pv.mirror.rot,res=pv.mirror.res},pv.mirror.res.ok and 'ok' or 'bad') end
        end
    end
    if selecting then
        if showHit and drag and drag.lo then self:Region(drag.lo,drag.hi) end
        for _,p in ipairs(selectionParts) do Item({type=p.type,pos=p.pos,rot=p.rot,res={cells=p._cells}},not drag and editor.selection[p.id] and 'erase' or 'ok') end
    end
    for _,p in ipairs(editor:Selected()) do for _,c in ipairs(p._cells) do self:Cell(c,Config.HexLinear(COLORS.selected,.85)) end end
    self.lines:Commit()
    self.volume:Commit()
    -- Return unused slots immediately so cycling types/pastes cannot pin old models.
    for i=#self.pool,math.min(count,self.limit)+1,-1 do self:Drop(self.pool[i]);self.pool[i]=nil end
    self:Face(showHit and not selecting and not stretch and editor.hit,(editor.tool=='build' or editor.tool=='stretch') and 'ok' or editor.tool)
end
function M:Dispose()
    self.gate:Cancel()
    for _,item in ipairs(self.pool) do self:Drop(item) end
    self.pool={};self.root:Dispose();self.lineMaterial:Dispose();self.faceMaterial:Dispose();self.volumeMaterial:Dispose()
end
return M
