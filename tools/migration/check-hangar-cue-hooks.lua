local checks,sounds=0,{}
local function Check(value,message) checks=checks+1;assert(value,message) end
local noop=function() end
package.loaded['audio.UiSound']={Play=function(id) sounds[#sounds+1]=id;return true end}
package.loaded['ui.SourceRichText']={}
local Toasts=assert(load(HOOK_SOURCES['scripts/ui/SourceToasts.lua']))()
local Salvage=assert(load(HOOK_SOURCES['scripts/ui/SalvagePage.lua']))()
package.loaded['ui.SalvagePage']=Salvage
local Hud=assert(load(HOOK_SOURCES['scripts/ui/GarageHud.lua']))()
local function App()
    return {homeTab='hangar',vehicleGate={Cancel=noop},vehicleSwitch={CancelDownload=noop},
        toasts=Toasts.New(),previews={},music={},HomeView=function(self,tab) self.lastHomeView=tab end}
end
for _,case in ipairs(HOOK_ORACLE.pageTabs) do
    local app=App();Hud.Create(app);local s=Hud.GetState()
    s.tab=case.same and case.id or 'hangar'
    s.salvage={tab=case.same and case.id or 'loadout'}
    sounds={}
    if case.salvage then Salvage.Tab(s,case.id,{quiet=case.quiet})
    else s.SetTab(case.id,{quiet=case.quiet}) end
    Check(#sounds==#case.sounds,'frozen public tab sound count')
    for i,id in ipairs(case.sounds) do Check(sounds[i]==id,'frozen public tab sound id') end
    Check((case.salvage and s.salvage.tab or s.tab)==case.id,'original tab state transition retained')
    Check(app.lastHomeView==(case.salvage and 'salvage' or case.id),'view target unchanged')
    Hud.Dispose()
end
for _,case in ipairs(HOOK_ORACLE.toasts) do
    local toasts=Toasts.New();sounds={};local item=toasts:Push('test',case.kind)
    Check(#sounds==#case.sounds,'frozen toast error sound condition')
    for i,id in ipairs(case.sounds) do Check(sounds[i]==id,'frozen toast error sound id') end
    Check(item and item.text=='test' and item.kind==case.kind,'toast presentation unchanged')
end
local toasts=Toasts.New();sounds={};toasts:Push('','bad');toasts:Dispose();toasts:Push('late','bad')
Check(#sounds==0,'empty or disposed notification cannot sound')
return checks
