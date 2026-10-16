local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Node(props)
    local n={props=props or {},children={}}
    for _,child in ipairs(n.props.children or {}) do n.children[#n.children+1]=child end
    function n:AddChild(child) self.children[#self.children+1]=child end
    function n:RemoveChild(child) for i,c in ipairs(self.children) do if c==child then table.remove(self.children,i);return end end end
    function n:Destroy() self.destroyed=true end
    return n
end
local sw,sh=1600,900
local root=Node()
package.loaded['urhox-libs/UI']={Panel=Node,Label=Node,ScrollView=Node,GetRoot=function() return root end,GetViewportSize=function() return sw,sh end}
local resource={Read=function() return {} end}
package.loaded['core.ResourceData']=resource
package.loaded['core.Coord']={}
package.loaded.Config={}
package.loaded['construction.Blueprint']={}
for _,name in ipairs({'construction.Placement','construction.EditHistory','construction.GridRay','core.Rotations','parts.Finish','construction.SelectionTools','construction.BuildGroups'}) do package.loaded[name]={} end
local defs={PARTS={},LIST={}}
for i=1,8 do local p={id='part'..i,name='Part '..i,cat='weapon'};defs.PARTS[p.id]=p;defs.LIST[#defs.LIST+1]=p end
package.loaded['parts.Defs']=defs
package.loaded['endless.Inventory']={Tier=function() return 1 end,Price=function() return 10 end}
package.loaded['ui.SourceDraw']={Number=tostring}
package.loaded['ui.VoxTheme']={Thumbnail=function(id) return id..'.png' end}
local widgets={Frame=Node,Button=Node}
package.loaded['ui.EndlessWidgets']=widgets
local Edit=dofile('scripts/endless/Edit.lua')
local Editor=dofile('scripts/construction/BuildEditor.lua')
package.loaded['construction.BuildStretch']=dofile('scripts/construction/BuildStretch.lua')
local Controls=dofile('scripts/controls/BuildInput.lua')
local calls=0
local original={name='entry',parts={}}
local bp={parts={}}
function bp:List() return {} end
function bp:Load(source) self.loaded=source end
local editor=setmetatable({bp=bp,selection={[7]=true},selectionOrder={7},selectionCorners={{id=7}},history={undoStack={1},redoStack={2}},
    clipboard={{type='part1'}},pasting=true,stretch={},hit={},preview={},focusIds={},boxing={},down={},hold={},rotorAim={},turretPreview={},dragPreview={}},Editor)
local inventory={hotbar={'cube','part1',false,'part2',false,false,false,false,false,false},active=2,revision=9}
local build={editor=editor}
build.controls=Controls.New(build);build.controls.pointer={};build.controls.selectionBox={};build.controls.dragSelection={};build.controls.touchPrimary=true
function build:Refresh() self.refreshes=(self.refreshes or 0)+1 end
function build:Notify(text) self.message=text end
local controller={run={blueprint=original,inventory={},credits=100}}
function controller:Buy(id)
    calls=calls+1
    if id=='bad' then return {ok=false,reason='cannot buy'} end
    self.run.credits=self.run.credits-10;self.run.inventory[id]=(self.run.inventory[id] or 0)+1;return {ok=true,price=10}
end
local car={Rebuild=function(self,source) self.rebuilt=source end}
local edit=Edit.New(controller);edit.host={editor=editor,blueprint=bp,car=car,inventory=inventory};edit.build=build
Check(edit:Buy('part3').ok,'purchase succeeds')
Check(calls==1 and controller.run.credits==90 and controller.run.inventory.part3==1,'one purchase delegates exactly one transaction')
Check(inventory.hotbar[3]=='part3' and inventory.hotbar[5]==false,'purchase fills first empty slot')
Check(inventory.active==2 and inventory.hotbar[2]=='part1','purchase preserves active slot and occupied slots')
Check(inventory.revision==10 and build.refreshes==1,'purchase refreshes changed hotbar once')
edit:Buy('part3')
local count=0;for i=1,10 do if inventory.hotbar[i]=='part3' then count=count+1 end end
Check(count==1 and controller.run.inventory.part3==2,'repeat purchase adds stock without duplicate shortcut')
Check(inventory.revision==10,'repeat purchase does not invalidate unchanged shortcuts')
local before=controller.run.credits
Check(not edit:Buy('bad').ok and controller.run.credits==before and inventory.hotbar[5]==false,'failed purchase leaves shortcuts and currency alone')
for i=1,10 do inventory.hotbar[i]='occupied'..i end
local snapshot=table.concat(inventory.hotbar,'|')
Check(edit:Buy('part4').ok and table.concat(inventory.hotbar,'|')==snapshot,'full hotbar purchase preserves all ten shortcuts')
edit:Reset()
Check(bp.loaded==original and car.rebuilt==bp,'reset rebuilds the entry blueprint')
Check(#editor.history.undoStack==0 and #editor.history.redoStack==0,'reset clears both history stacks')
Check(next(editor.selection)==nil and #editor.selectionOrder==0 and #editor.selectionCorners==0,'reset clears all selection representations')
Check(#editor.clipboard==0 and editor.pasting==false,'reset cancels pending paste')
for _,key in ipairs({'stretch','hit','preview','focusIds','boxing','down','hold','rotorAim','turretPreview','dragPreview'}) do Check(editor[key]==nil,'reset clears '..key) end
Check(editor.selectionVersion==1 and editor.dirty,'reset notifies real editor selection state')
Check(build.controls.pointer==nil and build.controls.selectionBox==nil and build.controls.dragSelection==nil and not build.controls.touchPrimary,'reset cancels real pointer and touch holds')
Check(table.concat(inventory.hotbar,'|')==snapshot and controller.run.inventory.part3==2,'reset preserves purchased stock and shortcut choices')
local Bar=dofile('scripts/ui/EndlessEditBar.lua')
build.buildCamera={Release=function() end}
local function FindButtons(node,out)
    out=out or {};if node.props.shop then out[#out+1]=node end
    for _,child in ipairs(node.children) do FindButtons(child,out) end
    return out
end
for _,size in ipairs({{1920,1080},{1600,900},{960,432},{840,378},{640,360},{480,270}}) do
    sw,sh=size[1],size[2]
    local modal=Bar.Shop(edit);local cards=FindButtons(modal);local bodyWidth=math.min(980,sw-48)-40
    local columns=math.max(1,math.floor((bodyWidth+6)/216));local cw=(bodyWidth-6*(columns-1))/columns
    Check(#cards==8,'shop retains all cards at '..sw)
    Check(cards[1].props.width==cw and cw*columns+6*(columns-1)<=bodyWidth+.00001,'shop fits source auto-fill columns at '..sw)
    Check(cw>=210 or columns==1,'shop source minimum card width at '..sw)
    modal:Close();Check(edit.shop==nil and modal.destroyed,'shop releases tree at '..sw)
end
sw,sh=1600,900
for i=1,10 do inventory.hotbar[i]=false end
controller.run.credits=100
local modal=Bar.Shop(edit);local card=FindButtons(modal)[1];local oldCalls=calls;card.props.onClick()
Check(calls==oldCalls+1 and inventory.hotbar[1]=='part1','real shop callback uses edit purchase adapter')
Check(modal.destroyed and edit.shop and edit.shop~=modal,'real shop callback rebuilds displayed currency and stock')
edit.shop:Close()
package.loaded['combat.CarUnit']={};package.loaded['salvage.Loot']={};package.loaded['salvage.Drops']={}
local Run=dofile('scripts/salvage/Run.lua')
local run=setmetatable({rules={}},Run)
local states={
    {prompt=nil,search=nil,swap=false,interactive=false},
    {prompt={title='crate'},search=nil,swap=false,interactive=true},
    {prompt={blocked=true},search=nil,swap=false,interactive=false},
    {prompt=nil,search={items={{state='hidden'},{state='scan'}}},swap=false,interactive=false},
    {prompt=nil,search={items={{state='shown'},{state='full'}}},swap=true,interactive=false},
    {prompt={blocked=true},search={items={{state='full'}}},swap=true,interactive=false},
    {prompt=nil,search={items={{state='shown'}}},swap=false,interactive=false},
    {prompt={title='crate'},search={items={{state='full'}}},finished=true,swap=false,interactive=false},
}
for i,state in ipairs(states) do
    run.rules.prompt=state.prompt;run.rules.search=state.search;run.rules.finished=state.finished
    run:TouchContext()
    Check(run.touchSwap==state.swap,'touch full-cargo role '..i)
    Check((run.touchPrompt~=nil)==state.interactive,'touch blocked-prompt filter '..i)
    if state.interactive then Check(run.touchPrompt==state.prompt,'touch prompt identity '..i) end
end
run.rules.finished=true;run.touchPrompt={};run.touchSwap=true;run:AfterStep(.016)
Check(run.touchPrompt==nil and run.touchSwap==false,'finished AfterStep clears stale mobile context')
return checks
