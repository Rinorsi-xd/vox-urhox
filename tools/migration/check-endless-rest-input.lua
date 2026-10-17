package.path='scripts/?.lua;'..package.path
local checks={};local function Check(ok,name) assert(ok,name);checks[#checks+1]=name end
for _,name in ipairs(imports) do package.loaded[name]={} end
package.loaded['core.ResourceData']={Read=function(name) return resources[name] end}
package.loaded['endless.Inventory']={Blueprint=function(value) return {ToTable=function() return value end} end}
package.loaded['parts.Defs']={PARTS={laser1={cat='weapon'}}}
package.loaded['urhox-libs.Platform.PlatformUtils']={IsWebPlatform=function() return true end}
package.loaded['ui.EndlessBanner']={Event=function() return nil,'' end}
local Session=require 'app.EndlessSession'
local Trial=require 'app.TrialSession'
local Pointer=require 'controls.DrivePointer'
local Run=require 'endless.Run'
MM_ABSOLUTE='absolute';MM_RELATIVE='relative'
local function Owner(g,touch,pending)
    input={mouseMode=MM_RELATIVE};local clears,muted=0,0
    local run=Run.New({},1,g.before);run.state=g.state;run:Drain()
    local session=setmetatable({scope=true,firing=true,touch=touch,controls={Clear=function() clears=clears+1 end},
        hud={Clear=function() clears=clears+1 end},weaponAudio={SetActive=function() muted=muted+1 end},
        drivingAudio={SetActive=function() muted=muted+1 end},feedbackAudio={SetActive=function() muted=muted+1 end}},Trial)
    session.pointer=Pointer.New(session);session.pointer.captured=g.locked;session.pointer.pending=pending==true
    local audio=0;local e=setmetatable({run=run,session=session,view={Event=function() end},
        audio={Update=function() audio=audio+1 end,Event=function() end}},Session)
    session.app={toasts={Push=function() end},store={Write=function() return true end}}
    session.camera={GetNode=function() return {} end};session.feedbackAudio.volume=1
    return e,session,function() return clears,muted,audio end
end
for index,g in ipairs(golden.cases) do
    for _,touch in ipairs({false,true}) do
        local e,s,counts=Owner(g,touch);local label='case '..index..' touch='..tostring(touch)
        e:Update(1/60);e:Update(1/60)
        local clears,muted,audio=counts()
        Check(s.pointer.captured==g.lockedAfter,'source lock state '..label)
        Check(muted==g.releases*3,'single release and no repeated pause '..label)
        Check(e.run.time==g.before.time and e.run.lives==g.before.lives,'input release does not reset run '..label)
        Check(s.dialog==nil,'no settings overlay '..label)
        Check(audio==2,'audio update continues '..label)
        if g.state=='rest' and g.supplies>0 then
            e:ChooseSupply(1)
            Check(#e.run.supplies==0 and e.run.repairs==g.after.repairs,'actual restored supply can be claimed once '..label)
            e:ChooseSupply(1)
            Check(e.run.repairs==g.after.repairs,'restored supply cannot duplicate '..label)
        end
    end
end
local g=golden.cases[1]
for _,candidate in ipairs(golden.cases) do if candidate.state=='rest' and candidate.supplies==1 then g=candidate;break end end
local e,s,counts=Owner(g,false,true);s.pointer.captured=false
e:Update(1/60);e:Update(1/60)
Check(not s.pointer.pending and not s.pointer.captured,'pending capture canceled before restored supply')
local _,muted=counts();Check(muted==3,'pending capture canceled once')
return checks
