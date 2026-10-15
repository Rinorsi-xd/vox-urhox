local UI=require 'urhox-libs/UI'
local W=require 'ui.TouchEditorWidgets'
local Prefs=require 'controls.TouchPreferences'
local Host=require 'ui.DialogHost'
local M={}
local specs={
    {'sens','镜头灵敏度',{{.6,'低'},{1,'中'},{1.5,'高'},{2.2,'很高'}}},
    {'size','按钮大小',{{.85,'小'},{1,'中'},{1.15,'大'}}},
    {'assist','瞄准辅助',{{true,'开'},{false,'关'}}},
    {'autoFire','对准自动开火',{{true,'开'},{false,'关'}}},
    {'plane','飞机操作',{{'point','指向（拖到哪飞哪）'},{'keys','键位'}}},
    {'build','建造方式',{{'tap','点哪放哪'},{'aim','准星'}}},
    {'fullscreen','全屏',{{true,'开'},{false,'关'}}}}
function M.Populate(parent,app,k,changed)
    local prefs=Prefs.Get(app);local refs={}
    parent:AddChild(UI.Label{text='触屏设置',fontFamily='vox-title',fontSize=15*k,color='#edf6ff',height=37*k,paddingLeft=18*k,paddingTop=8*k,marginTop=14*k,marginBottom=8*k,backgroundColor='#1d3852',flexShrink=0})
    local function Sync() for key,buttons in pairs(refs) do for _,entry in ipairs(buttons) do entry.button.props.selected=prefs[key]==entry.value end end end
    local function Set(key,value)
        prefs[key]=value;app:SaveTouchPrefs(prefs);Sync()
        if key=='fullscreen' and graphics:GetFullscreen()~=value then
            local ok,err=pcall(function() graphics:ToggleFullscreen() end)
            if not ok then app.toasts:Push('全屏切换失败：'..tostring(err),'bad') end
        end
        if changed then changed(key,value) end
    end
    for _,spec in ipairs(specs) do
        local key=spec[1];local row=UI.Panel{width='100%',height=40*k,marginTop=5*k,flexDirection='row',alignItems='center',gap=8*k,flexShrink=0}
        row:AddChild(UI.Label{text=spec[2],fontFamily='vox-title',fontSize=12*k,color='#aec4da',width=96*k,flexShrink=0})
        local buttons=UI.Panel{flexGrow=1,height=40*k,flexDirection='row',gap=4*k};row:AddChild(buttons);refs[key]={}
        for _,choice in ipairs(spec[3]) do
            local value=choice[1];local b=W.Button{text=choice[2],kind='segment',sourceScale=k,flexGrow=1,flexBasis=0,height=40*k,minWidth=0,padding=0,onClick=function() Set(key,value) end}
            buttons:AddChild(b);refs[key][#refs[key]+1]={value=value,button=b}
        end
        parent:AddChild(row)
    end
    Sync();return {refs=refs,Set=Set,Sync=Sync}
end
function M.Open(owner,options)
    options=options or {}
    if owner.buildCamera then owner.buildCamera:Release() elseif owner.Pause then owner:Pause() end
    local w,h=UI.GetViewportSize();local cssWidth=graphics:GetWidth()/math.max(1,graphics:GetDPR());local k=w/math.max(1,cssWidth)
    local modal=Host.Open(owner,'触屏操作',nil,{width=math.min(540*k,w-16*k)})
    local scroll=UI.ScrollView{width='100%',height=math.min(430*k,h-125*k),scrollY=true,bounces=false}
    modal.settings=M.Populate(scroll,owner.app,k,function()
        if owner.hud then
            if owner.hud.Clear then owner.hud.Clear() end
            if owner.hud.touchControls then owner.hud.touchControls.planeKeys=nil end
            if owner.hud.Refresh then owner.hud.Refresh() end
        end
    end);modal:AddContent(scroll)
    local done=W.Button{text=options.onDone and '返回设置' or '继续',kind='segment',sourceScale=k,width='100%',height=40*k,onClick=function() if options.onDone then options.onDone() else Host.Close(owner) end end}
    modal:AddContent(done);modal.actions={done=done};modal.scroll=scroll
    return modal
end
return M
