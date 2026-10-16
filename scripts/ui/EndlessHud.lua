local ShieldQuery=require("combat.ShieldQuery")
local Data=require("endless.Data")
local Blueprint=require("construction.Blueprint")
local EndlessBanner=require("ui.EndlessBanner")
local VoxTheme=require("ui.VoxTheme")

local UI=require('urhox-libs/UI')
local D=require('ui.SourceDraw')
local W=require('ui.EndlessWidgets')
local Config=require('endless.Data').config
local Panel=UI.Panel:Extend('VoxEndlessHud')
local M={}
local white={238,247,255,255};local muted={242,246,248,166};local blue={159,216,255,255};local gold={255,194,26,255}
local function Text(vg,t,x,y,size,color,font,align) D.Text(vg,tostring(t),x,y,size,color or white,font or 'vox-title',align) end
function Panel:Render(vg)
    D.Begin(vg);D.HudFont(vg);local s=self.session;local e=s.endless;local r=e.run;local box=self:GetAbsoluteLayout();local w,h=box.w,box.h
    if r.state=='editing' then return end
    local x,y=box.x+18,box.y+64
    Text(vg,'WAVE',x,y+30,13,muted,'vox-hud-medium');Text(vg,string.format('%02d',r.wave),x+64,y,46,white,'vox-display');Text(vg,'敌人 T'..r.tier,x+134,y+29,15,{255,138,61,255},'vox-hud-medium')
    D.Line(vg,x,y+48,x+240,y+48,{255,255,255,64})
    local sub
    if r.state=='combat' then local alive=0;for _ in pairs(r.alive) do alive=alive+1 end;sub='敌人 '..alive..' · 待出击 '..#r.queue..' · '..math.floor(r.waveTime)..' 秒'..(r.charge and ' · 敌人冲锋' or '')
    elseif r.state=='rest' then sub='波间休整' elseif r.state=='over' then sub='本局结束' else sub='准备出击 '..math.ceil(r.countdown)..' 秒' end
    Text(vg,sub,x,y+57,14,r.waveTime>=Config.chargeAfter-20 and {255,122,90,255} or {219,230,238,255},'vox-hud-medium')
    local right=box.x+w-18
    for i=1,Config.lives do local px=right-(Config.lives-i+1)*40
        D.Path(vg,{px+6,y,px+40,y,px+34,y+12,px,y+12});nvgFillColor(vg,D.Color(i<=r.lives and {242,246,248,255} or {255,255,255,38}));nvgFill(vg)
    end
    Text(vg,'金钱',right-130,y+32,12,muted,'vox-hud-medium');Text(vg,D.Number(r.credits),right,y+21,34,gold,'vox-display',NVG_ALIGN_RIGHT)
    Text(vg,'得分',right-110,y+68,12,muted,'vox-hud-medium');Text(vg,D.Number(math.floor(r.score)),right,y+63,20,white,'vox-display',NVG_ALIGN_RIGHT)
    if e.player.alive and ShieldQuery.Contains(e.shield,e.player:Position()) then
        local cx,cy=box.x+w*.5,box.y+h-64;Text(vg,'基地护盾 '..D.Number(math.ceil(r.shield.hp))..' / '..D.Number(r.shield.max),cx,cy-25,13,blue,'vox-hud-medium',NVG_ALIGN_CENTER)
        D.Rect(vg,cx-210,cy,420,6,{255,255,255,31});D.Rect(vg,cx-210,cy,420*math.max(0,r.shield.hp/r.shield.max),6,{46,168,255,255})
    end
    local banner=e.banner and e.banner.text or ''
    if banner~='' then D.Text(vg,banner,box.x+w*.5,box.y+h*.2,28,white,'vox-title',NVG_ALIGN_CENTER,0,false,nil,{{y=2,blur=12,color={0,0,0,255}}}) end
    if not s.touch then Text(vg,'W/S 油门 · A/D 转向 · 鼠标瞄准 / 左键开火 · 数字键换武器 · R 翻正 · G 波间改装 · Enter 下一波 · V 维修补给',box.x+w*.5,box.y+h-22,12,{242,246,248,160},'vox-title',NVG_ALIGN_CENTER) end
end
local function Summary(s,root)
    local e=s.endless;local r=e.result;local sw,sh=UI.GetViewportSize();local width=sw*.8
    local frame=W.Frame{position='absolute',left=sw*.1,top=sh*.05,width=width,maxHeight=sh*.8,padding=32,gap=12,pointerEvents='auto'};root:AddChild(frame)
    frame:AddChild(UI.Label{text='本局结束'..(e.isBest and ' · 新纪录' or ''),fontFamily='vox-title',fontSize=28,color='#eef7ff',height=40})
    frame:AddChild(UI.Label{text='种子 '..tostring(r.seed),fontFamily='vox-title',fontSize=14,color='#a8c3d4',height=24})
    local grid=UI.Panel{width='100%',flexDirection='row',flexWrap='wrap',gap=22};frame:AddChild(grid)
    for _,row in ipairs({{r.wave,'坚持波次'},{D.Number(math.floor(r.score)),'得分 · 最高 '..math.floor(e.best.score or 0)},{math.floor(r.time/60)..' 分 '..math.floor(r.time%60)..' 秒','用时'},{D.Number(math.floor(r.damage+.5)),'造成伤害'}}) do
        grid:AddChild(UI.Panel{width=(width-64-44)/3,height=76,children={UI.Label{text=tostring(row[1]),fontFamily='vox-title',fontSize=28,color='#eef7ff',height=38},UI.Label{text=row[2],fontFamily='vox-title',fontSize=14,color='#a8c3d4',height=24}}})
    end
    local kills={};for _,role in ipairs({'assault','heavy','sniper','hover','boss'}) do kills[#kills+1]=Data.roles[role].name..' '..(r.kills[role] or 0) end
    frame:AddChild(UI.Label{text='击杀 '..table.concat(kills,' · '),fontFamily='vox-title',fontSize=14,color='#a8c3d4',height=26})
    local actions=UI.Panel{width='100%',flexDirection='row',gap=12,height=44};frame:AddChild(actions)
    actions:AddChild(W.Button{text='再来一局',width=112,height=44,onClick=function() s.app.endlessAgain=true;s.wantsReturn=true end})
    actions:AddChild(W.Button{text='把这辆车存到车位',width=210,height=44,onClick=function()
        for i=1,20 do if not s.app.store:LoadSlot(i) then local ok,err=s.app.store:SaveSlot(i,Blueprint.New():Load(e.run.blueprint));s.app.toasts:Push(ok and '已保存到车位 '..i or err,ok and 'ok' or 'bad');return end end
        s.app.toasts:Push('车位已满，请先在机库腾出一个空位','warn')
    end})
    actions:AddChild(W.Button{text='回主页',width=112,height=44,onClick=function() s.wantsReturn=true end})
    return frame
end
function M.Attach(session,root)
    local hud=Panel{position='absolute',left=0,top=0,width='100%',height='100%',pointerEvents='none'};hud.session=session;root:AddChild(hud)
    local exit=W.Button{position='absolute',right=14,top=12,text='结束本局',width=116,height=44,onClick=function() session.endless.run:Finish();session.endless:Events() end};root:AddChild(exit)
    local state={root=hud,age=0,key=false,rest=nil,summary=nil}
    function state.Update(dt)
        state.age=state.age+(dt or 0);local e=session.endless;local r=e.run
        EndlessBanner.Update(e,r)
        hud:SetVisible(r.state~='editing');exit:SetVisible(r.state~='editing' and r.state~='over')
        if r.state=='over' and not state.summary then state.summary=Summary(session,root) end
        local key=r.state..':'..r.wave..':'..#r.supplies
        if state.key==key then return end;state.key=key
        if state.rest then root:RemoveChild(state.rest);state.rest:Destroy();state.rest=nil end
        if r.state=='rest' then
            local sw,sh=UI.GetViewportSize();local width=math.min(860,sw*.8)
            local box=UI.Panel{position='absolute',left=(sw-width)/2,top=sh*.29,width=width,paddingHorizontal=28,paddingVertical=18,backgroundColor={16,36,49,238},gap=12,pointerEvents='auto'};root:AddChild(box);state.rest=box
            box:AddChild(UI.Label{text='第 '..r.wave..' 波完成',fontFamily='vox-title',fontSize=14,color='#eef7ff',height=22,textAlign='center'})
            local hint=(r.wave+1)%5==0 and '下一波：Boss · 磐石 T'..math.min(5,r.tier+1) or '整理战车，准备下一波'
            box:AddChild(UI.Label{text=hint,fontFamily='vox-title',fontSize=14,color='#dbe6ee',height=22,textAlign='center'})
            local actions=UI.Panel{width='100%',height=44,flexDirection='row',justifyContent='center',gap=16};box:AddChild(actions)
            actions:AddChild(W.Button{text=(session.touch and '' or 'G ')..'改装',width=112,height=44,onClick=function() e:EnterEdit() end})
            actions:AddChild(W.Button{text=(session.touch and '' or 'Enter ')..'开始第 '..(r.wave+1)..' 波',disabled=#r.supplies>0,width=224,height=44,onClick=function() e:NextWave() end})
            box:AddChild(UI.Label{text=#r.supplies>0 and (r.wave%5==0 and '金色补给箱' or '补给箱')..' · 选择一件' or '补给已领取 · 可以改装或开始下一波',fontFamily='vox-title',fontSize=14,color='#eef7ff',height=24,textAlign='center'})
            if #r.supplies>0 then local grid=UI.Panel{width='100%',flexDirection='row',gap=16};box:AddChild(grid)
                for i,choice in ipairs(r.supplies) do local index=i;grid:AddChild(W.Button{text=choice.name,thumb=choice.type and VoxTheme.Thumbnail(choice.type) or nil,repair=not choice.type,subtitle=choice.type and 'T'..choice.tier..' · '..(choice.category=='weapon' and '武器' or choice.category=='movement' and '移动零件' or '功能零件') or choice.description,width=(width-56-32)/3,height=164,onClick=function() e:ChooseSupply(index) end}) end
            end
        end
    end
    state.Update(0);return state
end
return M
