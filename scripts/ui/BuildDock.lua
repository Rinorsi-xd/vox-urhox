-- Frozen 2026-10-12 dock: tools | hotbar | persistent palette | toggles.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Config=require 'Config'
local Defs=require 'parts.Defs'
local Row=Panel:Extend('VoxBuildDockRow')
function Row:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    D.Path(vg,{r.x+12,r.y,r.x+r.w-12,r.y,r.x+r.w,r.y+12,r.x+r.w,r.y+r.h,r.x,r.y+r.h,r.x,r.y+12})
    nvgFillColor(vg,nvgRGBA(21,42,64,255));nvgFill(vg);D.Rect(vg,r.x+12,r.y,r.w-24,1,{165,214,255,28})
end
local Status=Panel:Extend('VoxBuildDockStatus')
local tools={{'build','放置','build','1–0'},{'erase','删除','erase','X'},{'select','选择','select','Q'},{'stretch','拉伸','ruler','J'},{'paint','上色','brush','P'}}
function Status:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local e=self.session.editor
    local activeTool=self.session.selecting and 'select' or e.tool
    local spec=tools[1];for _,t in ipairs(tools) do if t[1]==activeTool then spec=t;break end end
    local name=Defs.PARTS[e.type].name;local color='原色'
    for _,c in ipairs(Config.PALETTE) do if not e.autoColor and c.hex==e.color then color=c.name;break end end
    local span=D.Width(vg,spec[2],15)+D.Width(vg,name,15)+D.Width(vg,color,15)+110
    local x=r.x+(r.w-span)/2
    nvgBeginPath(vg);nvgRect(vg,x-26,r.y,span+52,26);D.Gradient(vg,x-26,r.y,span+52,26,{9,10,12,0},{9,10,12,199},true)
    D.Icon(vg,spec[3],x,r.y+5,16,D.orange);x=x+22;D.Text(vg,spec[2],x,r.y+5,15);x=x+D.Width(vg,spec[2],15)+20
    D.Rect(vg,x,r.y+11,4,4,D.dim);x=x+12;D.Text(vg,name,x,r.y+5,15);x=x+D.Width(vg,name,15)+20
    D.Rect(vg,x,r.y+11,4,4,D.dim);x=x+12;local c=e.autoColor and 0xc9ced6 or e.color
    D.Rect(vg,x,r.y+7,12,12,{(c>>16)&255,(c>>8)&255,c&255,255});D.Text(vg,color,x+18,r.y+5,15,D.white)
end
local M={}
function M.Create(session,state,Action,root,layout)
    local editor=session.editor;local width,height=UI.GetViewportSize()
    local dock=UI.Panel{position='absolute',left=(width-layout.dock)/2,bottom=14,width=layout.dock,height=102,pointerEvents='box-none'}
    root:AddChild(dock);state.dock=dock
    local status=Status{position='absolute',left=0,top=0,width='100%',height=26,pointerEvents='none'};status.session=session;dock:AddChild(status)
    local row=Row{position='absolute',left=0,top=32,width='100%',height=70,paddingHorizontal=10,paddingVertical=8,flexDirection='row',alignItems='center',gap=10,pointerEvents='box-none'};dock:AddChild(row)
    local function Separator() row:AddChild(UI.Panel{width=1,height=40,backgroundColor={255,255,255,20},pointerEvents='none'}) end
    local toolRoot=UI.Panel{width=layout.tools,height=52,flexDirection='row',gap=4};row:AddChild(toolRoot)
    for _,t in ipairs(tools) do
        local button=Action(toolRoot,t[1],t[2],t[3],'tool',function()
            if t[1]=='select' then editor:SetTool('build');session.selecting=true
            elseif t[1]=='stretch' then editor:SetTool('stretch');session.selecting=false
            else editor:SetTool(t[1]);session.selecting=false end
        end,{width=layout.tool,height=52,key=t[4]})
        button.props.tooltip=t[2]
    end
    Separator();state.hotbar=require('ui.BuildHotbar').Create(session);row:AddChild(state.hotbar.root);Separator()
    local palette=UI.Panel{width=layout.paint,height=52,flexDirection='row',gap=8,alignItems='center'};row:AddChild(palette);state.paint=palette
    local now=Action(palette,'color','原色',nil,'dock-color',function() editor:SetTool('paint');session.selecting=false end,{width=width<=1440 and 84 or 99,height=52,hex=editor.color,auto=true})
    local channels=UI.Panel{width=50,height=49,gap=3,visible=false};palette:AddChild(channels);state.paintChannels=channels
    for _,channel in ipairs({{'shell','主色'},{'accent','装饰'}}) do
        Action(channels,channel[1],channel[2],nil,'channel',function() editor.paintChannel=channel[1] end,{width=50,height=23})
    end
    local cell=width<=1440 and 17 or 20;local stride=cell+3
    local grid=UI.Panel{width=stride*9-3,height=cell*2+3,pointerEvents='box-none'};palette:AddChild(grid);state.swatches={}
    local function Swatch(i,c,auto)
        local b=Action(grid,'swatch'..i,'',nil,'dock-swatch',function() editor.autoColor=auto; if c then editor.color=c.hex end end,
            {position='absolute',left=i%9*stride,top=math.floor(i/9)*stride,width=cell,height=cell,minWidth=0,minHeight=0,paddingHorizontal=0,paddingVertical=0,hex=c and c.hex,auto=auto,key=i==0 and '`' or i<=10 and tostring(i%10) or nil,tooltip=c and c.name or '原色'})
        if auto then state.autoSwatch=b else state.swatches[i]=b end
    end
    Swatch(0,nil,true);for i,c in ipairs(Config.PALETTE) do Swatch(i,c,false) end
    Separator();local toggles=UI.Panel{width=layout.toggles,height=52,flexDirection='row',gap=4};row:AddChild(toggles)
    local toggleWidth=(layout.toggles-8)/3
    Action(toggles,'mirror','镜像','mirror','toggle',function() editor.mirror=not editor.mirror end,{width=toggleWidth,height=52,key='M',tooltip='镜像'})
    Action(toggles,'xray','透视','eye','toggle',function() session:ToggleXray() end,{width=toggleWidth,height=52,key='V',tooltip='透视'})
    Action(toggles,'form','连块','cube','toggle',function() session:ToggleForm() end,{width=toggleWidth,height=52,key='F',tooltip='连块'})
    state.xrayButton=state.buttons.xray
    function state.RefreshDock()
        local painting=editor.tool=='paint';channels:SetVisible(painting)
        local extra=painting and 58 or 0;palette:SetWidth(layout.paint+extra);dock:SetStyle({width=layout.dock+extra,left=(width-layout.dock-extra)/2})
        now.props.hex=editor.color;now.props.auto=editor.autoColor
        now.props.text='原色';for _,c in ipairs(Config.PALETTE) do if not editor.autoColor and c.hex==editor.color then now.props.text=c.name;break end end
        for _,t in ipairs(tools) do state.buttons[t[1]].props.selected=t[1]=='select' and session.selecting or t[1]~='select' and not session.selecting and editor.tool==t[1] and not editor.pasting end
        state.autoSwatch.props.selected=editor.autoColor
        state.buttons.form.props.selected=editor.joinNew==true
    end
    return dock
end
return M
