package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
for _,name in ipairs(imports) do package.loaded[name]={} end
package.loaded['core.ResourceData']={Read=function(name) return resources[name] end}
local Widget={};Widget.__index=Widget
function Widget.New(props)
    local self=setmetatable({props=props or {},children={}},Widget)
    for _,child in ipairs(self.props.children or {}) do self:AddChild(child) end
    return self
end
function Widget:AddChild(child) self.children[#self.children+1]=child end
function Widget:SetStyle(props) for key,value in pairs(props) do self.props[key]=value end end
function Widget:ClearChildren() self.children={} end
function Widget:Destroy() end
local Component=setmetatable({},{__call=function(_,props) return Widget.New(props) end})
package.loaded['urhox-libs/UI']={Panel=Component,ScrollView=Component}
package.loaded['ui.SalvageButton']=Component
package.loaded['ui.SalvageItem']=Component
package.loaded['ui.SalvagePaint']={Page=Component,Surface=Component,Text=Component,Value=function() return 1000000 end}
package.loaded['ui.SourceParagraph']={New=function() return {} end}
package.loaded['ui.SourceDraw']={Number=tostring}
package.loaded['ui.InventorySearch']=Component
package.loaded['ui.SalvageQuantity']={Create=function() return Component{} end}
package.loaded['storage.RecordNumbers']={Count=function(n) return type(n)=='number' and n>=0 and n%1==0 end}
package.loaded['ui.GarageHud']={GetState=function() return nil end}
local map={salvage=true}
package.loaded['app.DriveMaps']={salvage=map}
local spec={ok=true}
package.loaded['drive.VehicleSpec']={Build=function() return spec end}
local Lobby=require 'app.SalvageLobby'
local Page=require 'ui.SalvagePage'
local App=require 'app.HangarApp'
local DebugActions=require 'app.DebugActions'
local function Find(node,text)
    if node.props.text==text then return node end
    for _,child in ipairs(node.children) do local value=Find(child,text);if value then return value end end
end
local function Owner(debug,quantity,owned)
    local notes={};local writes=0
    local app=setmetatable({debugEnabled=debug,ownsScene=true,mode='hangar',lobby='salvage',loader={state='idle'},
        vehicleGate={Cancel=function() end},blueprint={name='测试车',List=function() return {{type='cube'}} end},
        toasts={Push=function(_,text) notes[#notes+1]=text end},loadingFlow={Open=function() error('REACHED_LOADING',0) end}},App)
    local lobby=setmetatable({app=app,data={v=1,credits=8000,items={['part:cube']=owned},op=1},
        Usage=function() return {['part:cube']=quantity} end,
        Save=function() writes=writes+1;return true end},Lobby)
    app.salvageLobby=lobby
    local owner={app=app,width=1920,height=1080,Track=function(value) return value end,
        salvage={tab='loadout',gear={},stash=false,qty=1}}
    return owner,notes,function() return writes end
end
for _,debug in ipairs({false,'1',true}) do
    for _,quantity in ipairs({1000,20000}) do
        local owner,notes,writes=Owner(debug,quantity,999)
        local lobby=owner.app.salvageLobby
        local label=' debug='..tostring(debug)..' quantity='..quantity
        Check(lobby:Shortfall()['part:cube']==quantity-999,'strict inventory remains real'..label)
        local page=Page.Create(owner);local depart=Find(page,'出发')
        Check(depart~=nil and depart.props.disabled==(debug~=true),'button gate'..label)
        local called=0;owner.app.EnterTrial=function() called=called+1;return true end
        local result=Page.Deploy(owner)
        Check(called==(debug==true and 1 or 0) and result==(debug==true),'callback gate'..label)
        owner.app.EnterTrial=nil
        local ok,value=pcall(App.EnterTrial,owner.app,'salvage')
        Check((not ok and value=='REACHED_LOADING')==(debug==true),'app gate'..label)
        Check(writes()==0 and lobby:Owned('part:cube')==999 and lobby.data.credits==8000,'debug never grants stock or cash'..label)
    end
end
for _,debug in ipairs({false,true}) do
    local owner,notes,writes=Owner(debug,3,999)
    local page=Page.Create(owner);Check(not Find(page,'出发').props.disabled,'sufficient inventory button '..tostring(debug))
    local ok,value=pcall(App.EnterTrial,owner.app,'salvage')
    Check(not ok and value=='REACHED_LOADING','sufficient inventory enters '..tostring(debug))
    spec.ok=false;spec.reason='INVALID VEHICLE'
    Check(App.EnterTrial(owner.app,'salvage')==false and notes[#notes]=='INVALID VEHICLE','debug preserves vehicle validity '..tostring(debug))
    spec.ok=true;spec.reason=nil
    local old=resources['UI/Outgame.json'].ops[1].minValue
    resources['UI/Outgame.json'].ops[1].minValue=1000000000
    Check(App.EnterTrial(owner.app,'salvage')==false and notes[#notes]:find('带入价值不足',1,true),'debug preserves operation tier '..tostring(debug))
    resources['UI/Outgame.json'].ops[1].minValue=old
    Check(writes()==0,'all launch checks are read only '..tostring(debug))
end
local owner=Owner(nil,1000,999)
Check(next(owner.app.salvageLobby:DeploymentShortfall())~=nil,'missing debug flag remains strict')
owner.app.debugEnabled=true
Check(next(owner.app.salvageLobby:DeploymentShortfall())==nil,'enabling debug applies immediately')
owner.app.debugEnabled=false
Check(owner.app.salvageLobby:DeploymentShortfall()['part:cube']==1,'disabling debug restores strict checks')
local function Parts(count)
    local out={};for i=1,count do out[i]={'cube'} end;return out
end
for _,debug in ipairs({false,true}) do
    local owner=Owner(debug,0,999);local app=owner.app;local lobby=app.salvageLobby
    lobby.Usage=nil
    app.blueprint.ToTable=function() return {parts=Parts(800)} end
    app.bays={active=1,Slots=function() return {{parts=Parts(800)},{parts=Parts(800)}} end}
    Check(lobby:Usage()['part:cube']==1600,'actual aggregate garage usage '..tostring(debug))
    Check(lobby:Shortfall()['part:cube']==601,'actual multi-car shortfall '..tostring(debug))
    for _,action in ipairs({'svGo','mapSalvage'}) do
        local ok,value=pcall(DebugActions.Execute,app,{},action)
        Check((not ok and value=='REACHED_LOADING')==debug,'debug action shares app gate '..action..' '..tostring(debug))
    end
end
return checks
