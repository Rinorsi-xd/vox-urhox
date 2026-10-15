local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Button=require 'ui.SourceButton'
local Controls=require 'ui.SourceGraphicsControls'
local function Metrics()
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    local compact=require('controls.TouchMode').Enabled() and math.min(w,h)/math.max(1,graphics:GetDPR())<=600
    local refH=compact and 600 or 1080
    return math.min(w/(refH*16/9),h/refH)/UI.GetScale(),compact
end
local Heading=UI.Panel:Extend('VoxGraphicsHeading')
function Heading:Render(vg)
    require('ui.SourceDraw').Begin(vg);local r=self:GetAbsoluteLayout()
    local k=self.props.sourceScale
    nvgSave(vg);nvgScale(vg,k,k)
    require('ui.SourceModal').DrawHeading(vg,r.x/k,r.y/k,r.w/k,'画面设置','调整会立即生效并自动保存',self.props.compact)
    nvgRestore(vg)
end
local M={}
local specs={
    {'bloom','泛光（灯晕）',0,.8,.01,function(v) return math.floor(v*100+.5)..'%' end},
    {'mist','柔光（柔焦）',0,.2,.005,function(v) return math.floor(v/.2*100+.5)..'%' end},
    {'exposure','曝光',.6,1.4,.01,function(v) return string.format('%.2f',v) end},
    {'vignette','暗角',0,.6,.01,function(v) return math.floor(v*100+.5)..'%' end},
    {'grain','胶片颗粒',0,.06,.002,function(v) return string.format('%g',math.floor(v*1000+.5)/10) end},
}
function M.Open(owner,options)
    options=options or {}
    if owner.Pause then owner:Pause() end
    local settings=owner.app.graphicsSettings
    local k,compact=Metrics()
    local modal=Host.Open(owner,'画面设置',function()
        local ok,err=settings:Flush()
        if not ok then Host.Notify(owner,'画面设置保存失败：'..tostring(err),'error') end
    end,{width=780*k,fullScroll=true,sourceScale=k})
    modal.controls={};modal.rows={};modal.sourceScale=k;modal.compact=compact
    local _,h=UI.GetViewportSize()
    local natural=(compact and 467 or 527)*k
    local scroll=UI.ScrollView{width='100%',height=math.min(natural,h*.86),sourceNaturalHeight=natural,flexShrink=0}
    scroll:AddChild(Heading{width='100%',height=(compact and 66 or 94)*k,sourceScale=k,compact=compact,flexShrink=0})
    local body=UI.Panel{width='100%',paddingHorizontal=(compact and 18 or 28)*k,paddingBottom=(compact and 16 or 24)*k,flexShrink=0}
    local rows=UI.Panel{width='100%',gap=2*k,flexShrink=0}
    local function Row(label,height,valueText)
        local row=Controls.Row{width='100%',height=(height-(compact and 4 or 0))*k,sourceScale=k,flexShrink=0,label=label,valueText=valueText}
        rows:AddChild(row);modal.rows[#modal.rows+1]=row;return row
    end
    local choices=UI.Panel{position='absolute',left=(compact and 122 or 158)*k,right=(compact and 86 or 98)*k,top=(compact and 9 or 11)*k,height=34*k,flexDirection='row',gap=5*k}
    modal.controls.quality={}
    for _,spec in ipairs({{'high','高'},{'medium','中'},{'low','低'}}) do
        local key=spec[1]
        local button=Button{text=spec[2],sourceKind='flat',sourceScale=k,height=34*k,flexGrow=1,flexBasis=0,
            selected=settings.data.quality==key,disabled=not settings:Supports('quality'),sourceOpacity=settings:Supports('quality') and 1 or .45,
            onClick=function() if settings:Set('quality',key) then for k,b in pairs(modal.controls.quality) do b.props.selected=k==key end end end}
        choices:AddChild(button);modal.controls.quality[key]=button
    end
    Row('画质',57):AddChild(choices)
    for _,spec in ipairs(specs) do
        local key=spec[1]
        local row=Row(spec[2],47,function() return spec[6](settings.data[key]) end)
        local slider=Controls.Slider{position='absolute',left=(compact and 124 or 160)*k,right=(compact and 84 or 96)*k,top=(compact and 13 or 15)*k,height=16*k,sourceScale=k,
            min=spec[3],max=spec[4],step=spec[5],thumbSize=16*k,value=settings.data[key],focusable=true,
            disabled=not settings:Supports(key),onChange=function(self,value)
                if not settings:Set(key,value) then self.props.value=settings.data[key] end
            end}
        row:AddChild(slider);modal.controls[key]=slider
    end
    local ao=Controls.Checkbox{position='absolute',left=(compact and 122 or 158)*k,right=(compact and 86 or 98)*k,top=(compact and 9 or 11)*k,height=22*k,sourceScale=k,
        checked=settings.data.ao,disabled=not settings:Supports('ao'),
        onClick=function(self) if settings:Set('ao',not settings.data.ao) then self.props.checked=settings.data.ao end end}
    Row('环境光遮蔽',45):AddChild(ao);modal.controls.ao=ao
    body:AddChild(rows)
    local buttonHeight=(compact and 44 or 40)*k
    modal.actions={reset=Button{text='恢复默认',sourceKind='dialog',sourceScale=k,width=101.609375*k,height=buttonHeight,
        onClick=function() settings:Reset();M.Open(owner,options) end},
        done=Button{text=options.onDone and '返回设置' or '完成',sourceKind='primary',sourceScale=k,width=(options.onDone and 116 or 71.8125)*k,height=buttonHeight,onClick=function() if options.onDone then options.onDone() else Host.Close(owner) end end}}
    body:AddChild(UI.Panel{width='100%',flexDirection='row',justifyContent='flex-end',height=buttonHeight,marginTop=20*k,gap=8*k,flexShrink=0,
        children={modal.actions.reset,modal.actions.done}})
    scroll:AddChild(body);modal:AddContent(scroll);modal.scroll=scroll
    owner.dialogTick=function()
        if owner.dialog~=modal then return end
        local currentScale,currentCompact=Metrics()
        if math.abs(currentScale-k)>.00001 or currentCompact~=compact then M.Open(owner,options) end
    end
    return modal
end
return M
