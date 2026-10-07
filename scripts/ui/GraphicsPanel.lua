local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Button=require 'ui.SourceButton'
local Controls=require 'ui.SourceGraphicsControls'
local Heading=UI.Panel:Extend('VoxGraphicsHeading')
function Heading:Render(vg)
    require('ui.SourceDraw').Begin(vg);local r=self:GetAbsoluteLayout()
    require('ui.SourceModal').DrawHeading(vg,r.x,r.y,r.w,'画面设置','调整会立即生效并自动保存')
end
local M={}
local specs={
    {'bloom','泛光（灯晕）',0,.8,.01,function(v) return math.floor(v*100+.5)..'%' end},
    {'mist','柔光（柔焦）',0,.2,.005,function(v) return math.floor(v/.2*100+.5)..'%' end},
    {'exposure','曝光',.6,1.4,.01,function(v) return string.format('%.2f',v) end},
    {'vignette','暗角',0,.6,.01,function(v) return math.floor(v*100+.5)..'%' end},
    {'grain','胶片颗粒',0,.06,.002,function(v) return string.format('%g',math.floor(v*1000+.5)/10) end},
}
function M.Open(owner)
    local settings=owner.app.graphicsSettings
    local modal=Host.Open(owner,'画面设置',function()
        local ok,err=settings:Flush()
        if not ok then Host.Notify(owner,'画面设置保存失败：'..tostring(err),'error') end
    end,{width=780,fullScroll=true})
    modal.controls={};modal.rows={}
    local _,h=UI.GetViewportSize()
    local scroll=UI.ScrollView{width='100%',height=math.min(527,h*.86),sourceNaturalHeight=527,flexShrink=0}
    scroll:AddChild(Heading{width='100%',height=94,flexShrink=0})
    local body=UI.Panel{width='100%',paddingHorizontal=28,paddingBottom=24,flexShrink=0}
    local rows=UI.Panel{width='100%',gap=2,flexShrink=0}
    local function Row(label,height,valueText)
        local row=Controls.Row{width='100%',height=height,flexShrink=0,label=label,valueText=valueText}
        rows:AddChild(row);modal.rows[#modal.rows+1]=row;return row
    end
    local choices=UI.Panel{position='absolute',left=158,right=98,top=11,height=34,flexDirection='row',gap=5}
    modal.controls.quality={}
    for _,spec in ipairs({{'high','高'},{'medium','中'},{'low','低'}}) do
        local key=spec[1]
        local button=Button{text=spec[2],sourceKind='flat',height=34,flexGrow=1,flexBasis=0,
            selected=settings.data.quality==key,disabled=not settings:Supports('quality'),sourceOpacity=settings:Supports('quality') and 1 or .45,
            onClick=function() if settings:Set('quality',key) then for k,b in pairs(modal.controls.quality) do b.props.selected=k==key end end end}
        choices:AddChild(button);modal.controls.quality[key]=button
    end
    Row('画质',57):AddChild(choices)
    for _,spec in ipairs(specs) do
        local key=spec[1]
        local row=Row(spec[2],47,function() return spec[6](settings.data[key]) end)
        local slider=Controls.Slider{position='absolute',left=160,right=96,top=15,height=16,
            min=spec[3],max=spec[4],step=spec[5],thumbSize=16,value=settings.data[key],focusable=true,
            disabled=not settings:Supports(key),onChange=function(self,value)
                if not settings:Set(key,value) then self.props.value=settings.data[key] end
            end}
        row:AddChild(slider);modal.controls[key]=slider
    end
    local ao=Controls.Checkbox{position='absolute',left=158,right=98,top=11,height=22,
        checked=settings.data.ao,disabled=not settings:Supports('ao'),
        onClick=function(self) if settings:Set('ao',not settings.data.ao) then self.props.checked=settings.data.ao end end}
    Row('环境光遮蔽',45):AddChild(ao);modal.controls.ao=ao
    body:AddChild(rows)
    modal.actions={reset=Button{text='恢复默认',sourceKind='dialog',width=101.609375,height=40,
        onClick=function() settings:Reset();M.Open(owner) end},
        done=Button{text='完成',sourceKind='primary',width=71.8125,height=40,onClick=function() Host.Close(owner) end}}
    body:AddChild(UI.Panel{width='100%',flexDirection='row',justifyContent='flex-end',height=40,marginTop=20,gap=8,flexShrink=0,
        children={modal.actions.reset,modal.actions.done}})
    scroll:AddChild(body);modal:AddContent(scroll);modal.scroll=scroll
    return modal
end
return M
