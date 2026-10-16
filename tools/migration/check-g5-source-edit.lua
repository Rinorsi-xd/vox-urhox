-- The main fixture leaves the actual production modules and adapters loaded.
local Edit=require 'endless.Edit'
local Editor=require 'construction.BuildEditor'
local Controls=require 'controls.BuildInput'
local Bar=require 'ui.EndlessEditBar'
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function Find(node,id)
    if node.props.shop and node.props.text=='Part '..id:sub(5) then return node end
    for _,child in ipairs(node.children) do local found=Find(child,id);if found then return found end end
end
for _,case in ipairs(sourceEdit.cases) do
    local c=case.config
    local bp={parts={},List=function() return {} end,Load=function(self,value) self.loaded=value end}
    local editor=setmetatable({bp=bp,selection={[7]=true},selectionOrder={7},selectionCorners={{id=7}},
        history={undoStack={1},redoStack={2}},clipboard={{type='part1'}},pasting=true},Editor)
    local transient={'hit','preview','focusIds','boxing','down','hold','stretch','rotorAim','turretPreview'}
    for _,key in ipairs(transient) do editor[key]={} end
    local inventory={hotbar={table.unpack(c.hotbar)},active=c.active,revision=0}
    local build={editor=editor,Refresh=function() end,Notify=function() end,buildCamera={Release=function() end}}
    build.controls=Controls.New(build)
    local calls=0
    local controller={run={blueprint={name='entry',parts={}},credits=c.credits,inventory={}}}
    function controller:Buy(id)
        calls=calls+1
        if id==self.failure then return {ok=false,reason='controlled failure'} end
        self.run.credits=self.run.credits-10;self.run.inventory[id]=(self.run.inventory[id] or 0)+1
        return {ok=true,price=10}
    end
    local car={Rebuild=function(self) self.rebuilds=(self.rebuilds or 0)+1 end}
    local edit=Edit.New(controller);edit.host={editor=editor,blueprint=bp,car=car,inventory=inventory};edit.build=build
    for i,frame in ipairs(case.frames) do
        if frame.action=='reset' then edit:Reset()
        else
            local id=frame.action:match('^fail:(.+)$') or frame.action
            controller.failure=frame.action:match('^fail:(.+)$')
            if not edit.shop then Bar.Shop(edit) end
            local button=Find(edit.shop,id);assert(button,'Missing production shop callback: '..id);button.props.onClick()
        end
        local label=c.name..' source callback '..i..' '
        Check(Same(inventory.hotbar,frame.hotbar),label..'hotbar')
        Check(inventory.active==frame.active,label..'active slot')
        Check(controller.run.credits==frame.credits,label..'credits')
        Check(Same(controller.run.inventory,frame.stock),label..'stock')
        Check(calls==frame.calls,label..'transaction count')
        if frame.reset then
            local r=frame.reset
            Check(Same(bp.loaded,r.loaded),label..'entry blueprint')
            Check(#editor.history.undoStack==r.undo and #editor.history.redoStack==r.redo,label..'history')
            Check(next(editor.selection)==nil and r.selection==0,label..'selection')
            Check(#editor.clipboard==0 and r.clipboard and editor.pasting==r.pasting,label..'paste')
            for j,key in ipairs(transient) do Check(editor[key]==nil and r.transient[j],label..key) end
            Check(car.rebuilds==r.rebuilds and editor.dirty==r.dirty,label..'rebuild')
        end
    end
    if edit.shop then edit.shop:Close() end
end
return checks
