-- Isolated read-only F8 snapshot, appended after the standard QA probe.
do
local UI=require 'urhox-libs/UI'
local Defs=require 'parts.Defs'
local function Digest(value)
    local encoded=cjson.encode(value);local hash=2166136261
    for i=1,#encoded do hash=((hash~encoded:byte(i))*16777619)&0xffffffff end
    return string.format('%08x:%d',hash,#encoded)
end
local function Rect(widget)
    if not widget or not widget.node then return false end
    local r=widget:GetAbsoluteLayoutForHitTest();return {r.x,r.y,r.w,r.h}
end
local function Snapshot()
    local app=VOX_HANGAR and VOX_HANGAR.app
    local trial=VOX_TRIAL and VOX_TRIAL.session
    local edit=trial and trial.endless and trial.endless.edit
    local build=edit and edit.build or app and app.build
    local width,height=UI.GetViewportSize()
    local state={width=width,height=height,build=build~=nil,inventory=false}
    if not build then return state end
    local panel=build.inventoryPanel;local inv=build.inventory
    state.dialog=build.dialog~=nil
    state.selection={active=inv.active,hotbar=inv.hotbar,type=build.editor.type,empty=build.editor.emptySlot==true}
    state.content={blueprint=Digest(build.editor.bp:ToTable()),undo=#build.editor.history.undoStack,redo=#build.editor.history.redoStack}
    state.mode=edit and 'endless' or app.lobby
    if state.mode=='salvage' then state.content.stock=Digest(app.salvageLobby.data) end
    if edit then state.content.stock=Digest(edit.controller.run.inventory) end
    local focus=UI.GetFocus()
    state.focus={part=focus and focus.props.partType or false,search=panel and focus==panel.search or false,close=panel and focus==panel.closeButton or false,disabled=focus and focus.props.disabled==true or false}
    if not panel then return state end
    state.inventory=true;state.hover=panel.hoverType or false;state.query=panel.model.query
    state.search=Rect(panel.search);state.close=Rect(panel.closeButton);state.cards={}
    for _,row in pairs(panel.list.pool_.inUse) do for _,cell in ipairs(row.cells) do
        if cell.type and cell.root:IsVisible() then state.cards[#state.cards+1]={id=cell.type,rect=Rect(cell.root),disabled=cell.root.props.disabled==true,unavailable=panel:Unavailable(cell.type)} end
    end end
    for _,def in ipairs(panel.results) do if panel:Unavailable(def.id) and def.cat=='weapon' then
        state.missing={id=def.id,name=def.name};break
    end end
    return state
end
local update=HandleUpdate
local post=HandlePostUpdate
local ready=false
local pending=false
function HandleUpdate(...)
    if input:GetKeyPress(KEY_F8) then pending=true end
    update(...)
end
function HandlePostUpdate(...)
    post(...)
    if not ready then ready=true;print('INVENTORY_DIGIT_OBSERVER_READY') end
    if pending then
        pending=false
        print('INVENTORY_DIGIT_STATE '..cjson.encode(Snapshot()))
    end
end
end
