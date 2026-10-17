package.path='scripts/?.lua;'..package.path
local checks={}
local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local imports=dofile('tools/migration/g5-offline-imports.lua')
imports.Exclude({'construction.Prefab','construction.Blueprint','construction.Garage',
    'ui.Workshop','ui.BayPreviews','ui.GarageDialogs','ui.InventorySearch','ui.SalvageQuantity',
    'urhox-libs/UI','ui.SourceDraw','ui.SalvageButton','ui.SalvageItem','ui.SalvagePaint',
    'ui.SourceParagraph','ui.VoxTheme'})
package.loaded['core.ResourceData']={Read=function(name) return assert(resources[name],name) end}
local sounds={}
package.loaded['audio.UiSound']={Play=function(id) sounds[#sounds+1]=id end}
if mutantCode then package.preload['app.SalvageLobby']=assert(load(mutantCode)) end
local Lobby=require 'app.SalvageLobby'
local Page=require 'ui.SalvagePage'
for i,case in ipairs(fixtures.cases) do
    local notes={};sounds={}
    local items={};for id,n in pairs(case.items) do items[id]=n end
    local app={toasts={Push=function(_,text,kind) notes[#notes+1]={text=text,kind=kind} end}}
    local lobby=setmetatable({data={credits=case.credits,items=items},app=app},Lobby)
    function lobby:Usage() return case.usage end
    local saves=0
    function lobby:Save() saves=saves+1;return true end
    app.salvageLobby=lobby
    local owner={app=app,salvage={selected=case.id,qty=case.n,market=case.sell and 'sell' or 'buy'}}
    Page.Trade(owner)
    local expected=case.expected
    Check(Same(notes,expected.notes),'case '..i..' source business failure reaches actual page toast: '..case.name)
    Check(Same(lobby.data.items,expected.items),'case '..i..' failed trade preserves every stock count')
    Check(lobby.data.credits==expected.credits,'case '..i..' failed trade preserves credit balance')
    Check(owner.salvage.qty==expected.qty,'case '..i..' failed trade retains entered quantity')
    Check(Same(sounds,expected.sounds),'case '..i..' failed trade does not play purchase/sale sound')
    Check(saves==expected.saves,'case '..i..' failed trade does not write storage')
end
return checks
