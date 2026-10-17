-- Isolated read-only suffix for the retained editor, after production PostUpdate.
do
local Inv=require('endless.Inventory')
local Defs=require('parts.Defs')
local UI=require('urhox-libs/UI')
local Config=require('Config')
local Coord=require('core.Coord')
local GridRay=require('construction.GridRay')
local Placement=require('construction.Placement')
local sequence=0
local observerReady=false
local function Finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function Validate(value,path,seen)
    local t=type(value)
    if t=='number' then assert(Finite(value),'Non-finite endless observer number at '..path)
    elseif t=='table' then
        assert(not seen[value],'Cyclic endless observer table at '..path);seen[value]=true
        for k,v in pairs(value) do Validate(v,path..'.'..tostring(k),seen) end
        seen[value]=nil
    else assert(t=='nil' or t=='string' or t=='boolean','Unsupported endless observer '..t..' at '..path) end
end
local function Checksum(text)
    local hash=2166136261
    for i=1,#text do hash=((hash~text:byte(i))*16777619)&0xffffffff end
    return hash
end
local function Rect(widget)
    if not widget or not widget.node then return nil end
    local r=widget:GetAbsoluteLayoutForHitTest()
    if not (Finite(r.x) and Finite(r.y) and Finite(r.w) and Finite(r.h)) then return nil end
    return {r.x,r.y,r.w,r.h}
end
local function Widgets(widget,out)
    if not widget or not widget.node or not widget:IsVisible() then return end
    local p=widget.props
    if p.onClick then
        local rect=Rect(widget)
        out[#out+1]={text=p.text or '',disabled=p.disabled==true,rect=rect or false,layoutPending=rect==nil}
    end
    for _,child in ipairs(widget.children or {}) do Widgets(child,out) end
end
local function CandidatePlacement(editor,hit,forward)
    local kind=editor.type
    local p=Placement.For(kind,hit,hit.place,forward,editor.spin,editor.sampledRot)
    local result=editor.bp:Check(kind,p.pos,p.rot,editor.bounds)
    if not result.ok and hit.alt then
        p=Placement.For(kind,hit,hit.alt,forward,editor.spin,editor.sampledRot)
        result=editor.bp:Check(kind,p.pos,p.rot,editor.bounds)
    end
    return {ok=result.ok and not p.reason,reason=p.reason or result.reason,pos=p.pos,rot=p.rot}
end
local function RankCandidates(result)
    table.sort(result,function(a,b)
        if a.legal~=b.legal then return a.legal end
        if a.normal[2]~=b.normal[2] then return a.normal[2]>b.normal[2] end
        if a.cell[2]~=b.cell[2] then return a.cell[2]>b.cell[2] end
        return a.ordinal<b.ordinal
    end)
    while #result>100 do result[#result]=nil end
    return result
end
local function Candidates(edit,w,h)
    local result,seen={},{};local host=edit.host;local camera=host.camera.camera
    local eye=host.camera.node.worldPosition
    for _,part in ipairs(host.blueprint:List()) do for _,cell in ipairs(part._cells) do
        for _,dir in ipairs({{0,1,0},{1,0,0},{-1,0,0},{0,0,1},{0,0,-1}}) do
            local key=table.concat(cell,',')..':'..table.concat(dir,',')
            local neighbor=host.blueprint.cellIds[table.concat({cell[1]+dir[1],cell[2]+dir[2],cell[3]+dir[3]},',')]
            if not neighbor and not seen[key] then
                seen[key]=true
                local at=edit.root:LocalToWorld(Coord.Vec((cell[1]+dir[1]*.499)*Config.CELL,(cell[2]+.5+dir[2]*.499)*Config.CELL,(cell[3]+dir[3]*.499)*Config.CELL))
                local screen=camera:WorldToScreenPoint(at);local delta=at-eye
                if screen.x>.12 and screen.x<.88 and screen.y>.12 and screen.y<.7 and delta:DotProduct(host.camera.node.worldRotation*Vector3.FORWARD)>0 then
                    local ray=camera:GetScreenRay(screen.x,screen.y)
                    local o=edit.root:WorldToLocal(ray.origin);local d=edit.root.worldRotation:Inverse()*ray.direction
                    local hit=GridRay.Cast({-o.x,o.y,o.z},{-d.x,d.y,d.z},host.blueprint,160,false)
                    if hit.hit and hit.partId==part.id then
                        local placement=CandidatePlacement(edit.build.editor,hit,{-d.x,0,d.z})
                        result[#result+1]={part=part.id,type=part.type,cell=cell,normal=hit.normal,screen={screen.x*w,screen.y*h},yaw=math.atan(delta.x,-delta.z),pitch=math.asin(delta.y/delta:Length()),legal=placement.ok,placement=placement,ordinal=#result+1}
                    end
                end
            end
        end
    end end
    return RankCandidates(result)
end
local keyAudits=setmetatable({},{__mode='k'})
local function FocusState(build)
    local focus=UI.GetFocus()
    return {exists=focus~=nil,textInput=focus~=nil and focus.OnTextInput~=nil,
        playfield=focus==build.hud.playfield,partType=focus and focus.props and focus.props.partType or false,
        engine=input.focus==true,minimized=input.minimized==true,captured=build.buildCamera.captured==true,
        inventory=build.inventoryPanel~=nil,dialog=build.dialog~=nil}
end
local function AuditKeys(build)
    local audit=keyAudits[build]
    if audit then return audit end
    audit={attempts={}};keyAudits[build]=audit
    local original=build.Keys
    function build:Keys(...)
        local z,y=input:GetKeyPress(KEY_Z),input:GetKeyPress(KEY_Y)
        if not z and not y then return original(self,...) end
        local row={z=z,y=y,ctrl=input:GetKeyDown(KEY_CTRL),shift=input:GetKeyDown(KEY_SHIFT),focus=FocusState(self),
            before={parts=self.editor.bp:Size(),undo=#self.editor.history.undoStack,redo=#self.editor.history.redoStack}}
        local result=original(self,...)
        row.after={parts=self.editor.bp:Size(),undo=#self.editor.history.undoStack,redo=#self.editor.history.redoStack}
        audit.attempts[#audit.attempts+1]=row
        while #audit.attempts>12 do table.remove(audit.attempts,1) end
        return result
    end
    return audit
end
local function Snapshot()
    local trial=VOX_TRIAL and VOX_TRIAL.session
    local endless=trial and trial.endless
    local edit=endless and endless.edit
    local app=VOX_TRIAL and VOX_TRIAL.app or VOX_HANGAR and VOX_HANGAR.app
    local out={editing=edit~=nil,cards={},widgets={}}
    local w,h=UI.GetViewportSize();out.width=w;out.height=h
    out.mode=trial and 'trial' or 'hangar';out.loading=app and app.loadingFlow.active or false
    local home=require('ui.GarageHud').GetState();out.tab=home and home.tab or false
    Widgets(UI.GetRoot(),out.widgets)
    if endless then
        out.state=endless.run.state;out.wave=endless.run.wave;out.lives=endless.run.lives
        out.worldTime=trial.world.time;out.runTime=endless.run.time;out.supplies=endless.run.supplies
        out.queued=#endless.run.queue;out.enemies=0
        for _,entry in ipairs(endless.entries) do if entry.unit~=endless.player and entry.unit.alive then out.enemies=out.enemies+1 end end
    end
    if not edit or not edit.build then return out end
    local build=edit.build;local inv=build.inventory
    out.inputFocus=FocusState(build);out.keyAudit=AuditKeys(build)
    out.wave=endless.run.wave;out.lives=endless.run.lives
    out.worldTime=trial.world.time;out.runTime=endless.run.time
    out.hotbar=inv.hotbar;out.active=inv.active;out.type=build.editor.type
    out.parts=#edit.host.blueprint:List()
    out.remaining=Inv.Remaining(endless.run.inventory,edit.host.blueprint)
    out.owned=endless.run.inventory
    local preview=build.editor.preview
    out.preview=preview and {ok=preview.res and preview.res.ok or preview.ok or false,type=preview.type,pos=preview.pos,reason=preview.res and preview.res.reason,mirror=preview.mirror~=nil} or false
    out.hit=build.editor.hit
    out.blueprint=edit.host.blueprint:ToTable();out.counts=Inv.Count(edit.host.blueprint);out.partRecords={}
    for _,part in ipairs(edit.host.blueprint:List()) do out.partRecords[#out.partRecords+1]={id=part.id,type=part.type,pos=part.pos} end
    out.history={undo=#build.editor.history.undoStack,redo=#build.editor.history.redoStack}
    out.message=build.message
    out.mirror=build.editor.mirror;out.cameraMode=build.buildCamera.mode
    local flight=build.buildCamera.flight
    out.camera={captured=build.buildCamera.captured,yaw=flight.yaw,pitch=flight.pitch,pos=flight.pos}
    out.candidates=Candidates(edit,w,h)
    out.inventory=build.inventoryPanel~=nil
    local panel=build.inventoryPanel
    if panel then
        out.search=Rect(panel.search);out.query=panel.model.query
        out.close=Rect(panel.closeButton);out.focus=UI.GetFocus() and UI.GetFocus().props.partType or false
        out.drag=panel.dragType or false;out.slots={}
        for i,slot in ipairs(panel.hotbar.slots) do out.slots[i]=Rect(slot.widget) end
        for _,row in pairs(panel.list.pool_.inUse) do
            for _,cell in ipairs(row.cells) do
                local id=cell.type
                if id and cell.root:IsVisible() then
                    local def=Defs.PARTS[id]
                    out.cards[#out.cards+1]={id=id,name=def.name,limited=Inv.Limited(id),
                        disabled=cell.root.props.disabled==true,unavailable=panel:Unavailable(id),rect=Rect(cell.root)}
                end
            end
        end
    end
    return out
end
local post=HandlePostUpdate
function HandlePostUpdate(...)
    post(...)
    if not observerReady then
        observerReady=true
        print('ENDLESS_STOCK_OBSERVER_READY')
    end
    if not input:GetKeyPress(KEY_F8) then return end
    local snapshot=Snapshot();Validate(snapshot,'snapshot',{})
    local encoded=cjson.encode(snapshot)
    local okay,decoded=pcall(cjson.decode,encoded)
    assert(okay and decoded~=nil,'Incomplete endless observer JSON bytes='..#encoded..' tail='..encoded:sub(-120))
    local checksum=Checksum(encoded);sequence=sequence+1
    local pieces={};local at=1
    while at<=#encoded do
        local last=math.min(#encoded,at+599)
        while last<#encoded and encoded:byte(last+1)>=128 and encoded:byte(last+1)<192 do last=last-1 end
        pieces[#pieces+1]=encoded:sub(at,last);at=last+1
    end
    for i,piece in ipairs(pieces) do
        print('ENDLESS_STOCK_CHUNK '..cjson.encode({sequence=sequence,index=i,count=#pieces,bytes=#encoded,checksum=checksum,data=piece}))
    end
end
end
