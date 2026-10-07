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
    local self=setmetatable({pool={},limit=Quality.current.name=='mobile' and 16 or 48,maxCells=4096},M)
    self.root=parent:CreateChild('BuildPreview');self.root:SetScale(Config.CELL)
    self.lines=self.root:CreateChild('Cells'):CreateComponent('CustomGeometry')
    self.lineMaterial=NewMaterial('BuildLines');self.lines:SetMaterial(self.lineMaterial)
    self.face=self.root:CreateChild('HitFace'):CreateComponent('CustomGeometry')
    self.faceMaterial=NewMaterial('BuildFace');self.face:SetMaterial(self.faceMaterial)
    return self
end
function M:Drop(item)
    item.node:Dispose();item.models={};Assets.Release(item.resources);item.material:Dispose()
end
function M:Model(index,it,state)
    if index>self.limit then return end
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
function M:Refresh(editor,showHit)
    local pv=showHit and editor.preview;local count=0
    local key={editor.history.revision,editor.tool}
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
    local function Item(it,state)
        count=count+1;self:Model(count,it,state)
        local color=Config.HexLinear(COLORS[state],.65)
        for _,c in ipairs(it.res.cells) do self:Cell(c,color) end
    end
    if pv then
        if pv.paste then for _,it in ipairs(pv.paste) do Item(it,it.res.ok and 'ok' or 'bad') end
        else
            Item(pv,pv.res.ok and 'ok' or 'bad')
            if pv.mirror then Item({type=pv.type,pos=pv.mirror.pos,rot=pv.mirror.rot,res=pv.mirror.res},pv.mirror.res.ok and 'ok' or 'bad') end
        end
    end
    for _,p in ipairs(editor:Selected()) do for _,c in ipairs(p._cells) do self:Cell(c,Config.HexLinear(COLORS.selected,.85)) end end
    self.lines:Commit()
    -- Return unused slots immediately so cycling types/pastes cannot pin old models.
    for i=#self.pool,math.min(count,self.limit)+1,-1 do self:Drop(self.pool[i]);self.pool[i]=nil end
    self:Face(showHit and editor.hit,editor.tool=='build' and 'ok' or editor.tool)
end
function M:Dispose()
    for _,item in ipairs(self.pool) do self:Drop(item) end
    self.pool={};self.root:Dispose();self.lineMaterial:Dispose();self.faceMaterial:Dispose()
end
return M
