local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
package.path='scripts/?.lua;tools/migration/?.lua;'..package.path
cjson={null={}}
local resourceReads={}
local Imports=require 'g5-offline-imports'
Imports.Exclude(excludedImports)
package.loaded['core.ResourceData']={Read=function(name)
    resourceReads[name]=true;return assert(allResources[name],'Missing resource '..name)
end}
local focus=nil
local function Widget(props)
    return {props=props or {},Render=function() end,children={},AddChild=function(self,child) self.children[#self.children+1]=child end,
        SetStyle=function(self,style) for k,v in pairs(style) do self.props[k]=v end end}
end
package.loaded['urhox-libs/UI']={Panel=Widget,GetFocus=function() return focus end,ClearFocus=function() focus=nil end}
package.loaded['ui.InventoryChrome']={Card=Widget}
local Edit=require 'endless.Edit'
local Inventory=require 'construction.Inventory'
local BP=require 'construction.Blueprint'
local Inv=require 'endless.Inventory'
local Build=require 'app.BuildSession'
local Editor=require 'construction.BuildEditor'
local Controls=require 'controls.BuildInput'
local Panel=require 'ui.InventoryPanel'
local Keys=require 'ui.InventoryKeys'
KEY_RETURN=1;KEY_SPACE=2;KEY_DELETE=3;KEY_BACKSPACE=4
local caseIndex=0
for _,case in ipairs(golden.cases) do
    caseIndex=caseIndex+1
    local prefix='case '..caseIndex..' '..case.action..' '..case.id
    local bp=BP.New():Load(case.blueprint)
    local owned={[case.id]=case.owned}
    local editor=Editor.New(bp)
    local model=Inventory.New({hotbar={'cube','slope','heavy','corner',false,false,false,false,false,false},active=2})
    local saves,messages=0,{}
    local build=setmetatable({editor=editor,inventory=model,app={store={SaveBuildSettings=function() saves=saves+1;return true end},toasts={Push=function(_,text,kind) messages[#messages+1]={text=text,kind=kind} end}}},Build)
    build.controls=Controls.New(build)
    local edit=Edit.New({run={inventory=owned}});edit.host={blueprint=bp};edit.build=build
    edit:ConfigureStock()
    local beforeType=editor.type;local marker={};editor.preview=marker;build.controls.pointer=marker
    if case.action=='pick' then build:PickHotbar(case.id) else build:AssignHotbar(8,case.id) end
    Check(edit:CanSelect(case.id)==case.selectable,prefix..' actual remaining rule matches source')
    Check(model.active==case.active,prefix..' active slot matches source')
    for i=1,10 do Check(model.hotbar[i]==case.hotbar[i],prefix..' shortcut '..i..' matches source') end
    if case.blocked then
        Check(editor.type==beforeType and editor.preview==marker and build.controls.pointer==marker,prefix..' blocked selection preserves edit/input state')
        Check(saves==0 and #messages==1 and messages[1].text=='本局仓库没有这个零件' and messages[1].kind=='bad',prefix..' source rejection feedback without save')
    else
        Check(editor.type==case.id and build.controls.pointer==nil and saves==1,prefix..' allowed selection reaches actual editor and save')
    end
    local owner=setmetatable({columns=1,rowWidth=100,itemHeight=100,itemGap=0,model=model,session=build,hotbar={Refresh=function() end},Detail=function() end,closed=false},Panel)
    function owner:Close() self.closed=true end
    local row=owner:CreateRow();local cell=row.cells[1];cell.type=case.id;cell.root.props.partType=case.id
    owner.list={pool_={inUse={row}}};build.inventoryPanel=owner
    edit:StockCards()
    Check(owner:Unavailable(case.id)==not case.selectable,prefix..' actual panel availability matches source')
    Check(cell.root.props.disabled==not case.selectable,prefix..' disabled card follows remaining stock')
    if not case.selectable then
        local revision=model.revision
        cell.root.props.onDoubleTap()
        Check(not owner.closed and model.revision==revision,prefix..' depleted doubletap stays in inventory')
        local event={pointerId=1,pointerType='mouse',IsPrimaryButton=function() return true end}
        cell.root.props.onPointerDown(event)
        Check(not cell.root.OnPanStart(cell.root,event) and owner.dragType==nil,prefix..' depleted card cannot start drag')
        focus=cell.root;Check(not Keys.Activate(owner,KEY_RETURN),prefix..' depleted card cannot keyboard activate');focus=nil
    end
    -- Availability derives from live blueprint/owned stock, without a second ledger.
    if Inv.Limited(case.id) then
        owned[case.id]=case.used+1;edit:StockCards()
        Check(edit:CanSelect(case.id) and not owner:Unavailable(case.id) and not cell.root.props.disabled,prefix..' purchase or removal restores availability')
        owned[case.id]=case.used;edit:StockCards()
        Check(not edit:CanSelect(case.id) and owner:Unavailable(case.id) and cell.root.props.disabled,prefix..' installing last owned part exhausts availability')
    end
end
local History=require 'construction.EditHistory'
local bp=BP.New():Load({v=1,name='history',parts={{'laser1',0,0,0,0,0}}})
local editor=Editor.New(bp)
local edit=Edit.New({run={inventory={laser1=1}}});edit.host={blueprint=bp}
local card={props={},Render=function() end}
local owner={list={pool_={inUse={{cells={{type='laser1',root=card}}}}}}}
edit.build={inventoryPanel=owner}
edit:StockCards();Check(card.props.disabled and not edit:CanSelect('laser1'),'installed last part unavailable in parts grid')
local removed=bp:List()[1]
Check(editor.history:Commit({{op='remove',data=History.Snapshot(removed)}}),'disabled grid never blocks actual installed-part removal')
edit:StockCards();Check(not card.props.disabled and edit.remaining.laser1==1,'actual removal returns one available part')
Check(editor.history:Undo(),'actual removal undo succeeds')
edit:StockCards();Check(card.props.disabled and edit.remaining.laser1==0,'actual undo installs part without stock duplication')
Check(editor.history:Redo(),'actual removal redo succeeds')
edit:StockCards();Check(not card.props.disabled and edit.remaining.laser1==1,'actual redo returns exactly one part')
Check(editor.history:Commit({{op='add',data=History.Snapshot(removed)}}),'returned limited part can be installed again')
edit:StockCards();Check(card.props.disabled and edit.remaining.laser1==0,'reinstall exhausts same stock ledger')
Check(editor.history:Undo(),'actual install undo succeeds')
edit:StockCards();Check(not card.props.disabled and edit.remaining.laser1==1,'install undo restores availability')
Check(editor.history:Redo(),'actual install redo succeeds')
edit:StockCards();Check(card.props.disabled and edit.remaining.laser1==0,'install redo exhausts availability')
Check(rawget(Build,'CanSelect')==nil and rawget(Panel,'Unavailable')~=owner.Unavailable,'stock policy stays on owned instances')
return checks
