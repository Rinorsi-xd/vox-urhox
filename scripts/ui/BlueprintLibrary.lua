local UI=require 'urhox-libs/UI'
local Host=require 'ui.DialogHost'
local Button=require 'ui.SourceButton'
local Card=require 'ui.SourceLibraryCard'
local Heading=UI.Panel:Extend('VoxLibraryHeading')
function Heading:Render(vg)
    require('ui.SourceDraw').Begin(vg);local r=self:GetAbsoluteLayout()
    require('ui.SourceModal').DrawHeading(vg,r.x,r.y,r.w,'蓝图库',self.props.subtitle)
end
local M={}
local function Layout(slots,width,height)
    local occupiedRows=0
    for row=1,5 do
        for column=1,4 do if slots[(row-1)*4+column] then occupiedRows=occupiedRows+1;break end end
    end
    local content=math.min(780,width*.92)-56
    local function Natural(card) return 266+5*(card*10/16+33)+occupiedRows*24 end
    local gutter=Natural((content-30)/4)>height*.86 and 15 or 0
    local card=(content-gutter-30)/4
    return card,card*10/16,gutter,Natural(card)
end
function M.Open(owner,mode)
    mode=mode or 'load'
    local app=owner.app;local slots=app.bays:Slots();local used=0
    for _,data in ipairs(slots) do if data then used=used+1 end end
    local previews=false
    local modal=Host.Open(owner,'蓝图库',function() if previews then previews:FinishJob() end end,
        {width=780,fullScroll=true},function() if previews then previews:Dispose() end end)
    local function Reopen() local current=Host.Current(owner);if current then M.Open(current,mode) end end
    local width,height=UI.GetViewportSize()
    local cardWidth,pictureHeight,gutter,natural=Layout(slots,width,height)
    local rows={}
    for rowIndex=1,5 do
        local occupied=false;for column=1,4 do if slots[(rowIndex-1)*4+column] then occupied=true end end
        local rowHeight=pictureHeight+(occupied and 57 or 33)
        rows[rowIndex]=UI.Panel{width='100%',height=rowHeight,flexShrink=0,flexDirection='row',gap=10}
    end
    -- #modal .card scrolls as a whole, including its title and bottom actions.
    -- Windows Chromium reserves 15 CSS px for its vertical scrollbar.
    local scroll=UI.ScrollView{width='100%',height=math.min(natural,height*.86),paddingRight=gutter,flexShrink=0,showScrollbar=true,scrollbarInteractive=true,sourceNaturalHeight=natural}
    previews=require('ui.BayPreviews').New(scroll,app.previews)
    modal.cards={};modal.mode=mode;modal.tabs={}
    scroll:AddChild(Heading{width='100%',height=94,flexShrink=0,subtitle=string.format('%d / 20 已使用',used)})
    local body=UI.Panel{width='100%',paddingHorizontal=28,paddingBottom=24,flexShrink=0}
    local tabs=UI.Panel{width='100%',height=34,flexShrink=0,flexDirection='row',gap=6,marginBottom=14}
    for _,spec in ipairs({{'load','载入',58.609375},{'save','保存到…',83.421875}}) do
        local value=spec[1]
        local button=Button{text=spec[2],sourceKind='flat',selected=mode==value,width=spec[3],height=34,onClick=function() M.Open(owner,value) end}
        tabs:AddChild(button);modal.tabs[value]=button
    end
    body:AddChild(tabs)
    local grid=UI.Panel{width='100%',gap=10,flexShrink=0};body:AddChild(grid)
    local function Save(slot)
        Host.Close(owner);local ok,err=app.bays:Save(slot);Host.Notify(owner,ok and ('已保存到车位 '..slot) or err)
    end
    local function Load(slot)
        Host.Close(owner);local ok,err=app.bays:Restore(slot);Host.Notify(owner,ok and ('已载入车位 '..slot) or err)
    end
    for i,data in ipairs(slots) do
        local card=Card{width=cardWidth,height='100%',flexShrink=0,pictureHeight=pictureHeight,data=data or nil,mode=mode,slot=i,
            onClick=function()
                if mode=='save' then
                    if data then Host.Confirm(owner,'覆盖车位 '..i..'？','“'..data.name..'”将被当前战车替换。',function() Save(i) end,Reopen) else Save(i) end
                elseif data then
                    if app.bays.unsaved then Host.Confirm(owner,'载入保存版本？','当前未保存的改动将被替换。',function() Load(i) end,Reopen) else Load(i) end
                end
            end}
        if data then
            local picture=previews:Add(data,{height=pictureHeight,aspect=1.6,cut=12});picture:SetStyle({position='absolute',left=0,top=0})
            card:AddChild(picture)
            if mode=='load' then
                local delete=Card.Delete{card=card,width=30,height=30,position='absolute',top=6,right=6,onClick=function()
                    Host.Confirm(owner,'删除车位 '..i..'？','删除“'..data.name..'”，此操作无法撤销。',function()
                        local ok,err=app.bays:Delete(i);Host.Notify(owner,ok and '已删除' or err);Reopen()
                    end,Reopen)
                end}
                card:AddChild(delete);card.deleteButton=delete
            end
        end
        rows[math.ceil(i/4)]:AddChild(card);card.selectButton=card;modal.cards[i]=card
    end
    for _,row in ipairs(rows) do grid:AddChild(row) end
    modal.actions={done=Button{text='关闭',sourceKind='dialog',width=72,height=40,onClick=function() Host.Close(owner) end}}
    body:AddChild(UI.Panel{width='100%',height=40,flexShrink=0,flexDirection='row',justifyContent='flex-end',marginTop=20,children={modal.actions.done}})
    scroll:AddChild(body);modal:AddContent(scroll);modal.previews=previews;modal.scroll=scroll
    owner.dialogTick=function(dt)
        local w,h=UI.GetViewportSize()
        if w~=width or h~=height then
            width,height=w,h
            local cw,ph,gap,nh=Layout(slots,w,h)
            scroll:SetStyle({paddingRight=gap,height=math.min(nh,h*.86)});scroll.props.sourceNaturalHeight=nh
            for _,row in ipairs(rows) do
                local occupied=false
                for _,card in ipairs(row.children) do
                    card:SetWidth(cw);card.props.pictureHeight=ph
                    if card.props.data then occupied=true end
                    for _,child in ipairs(card.children) do if child.data then child:SetHeight(ph) end end
                end
                row:SetHeight(ph+(occupied and 57 or 33))
            end
        end
        previews:Update(dt)
    end
    return modal
end
return M
