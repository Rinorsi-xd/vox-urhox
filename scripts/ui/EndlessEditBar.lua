local Defs=require("parts.Defs")
local VoxTheme=require("ui.VoxTheme")

local UI=require('urhox-libs/UI')
local D=require('ui.SourceDraw')
local W=require('ui.EndlessWidgets')
local Inv=require('endless.Inventory')
local M={}
function M.Attach(edit,root)
    local sw=UI.GetViewportSize();local width=math.min(680,sw-48)
    local panel=W.Frame{position='absolute',left=(sw-width)/2,bottom=118,width=width,height=126,padding=12,gap=8,pointerEvents='auto'};root:AddChild(panel)
    panel:AddChild(UI.Label{text='本局改装 · 不限阶位 · 战场已暂停 · Esc 释放鼠标',fontFamily='vox-title',fontSize=14,color='#e0f3fa',height=20})
    local reason=UI.Label{text='',fontFamily='vox-title',fontSize=14,color='#e0f3fa',height=28};panel:AddChild(reason)
    local row=UI.Panel{width='100%',height=34,flexDirection='row',gap=8};panel:AddChild(row)
    row:AddChild(W.Button{text='重置本次改装',width=132,height=34,onClick=function() edit:Reset() end})
    local shop=W.Button{text='整备商店',width=180,height=34,onClick=function() M.Shop(edit) end};row:AddChild(shop)
    local depart=W.Button{text='Enter · 出发',width=136,height=34,onClick=function() edit:Depart() end};row:AddChild(depart)
    local last=false
    local function Update()
        panel:SetVisible(edit.build.inventoryPanel==nil)
        local result=edit:Validation();local text=result.ok and '校验通过，可返回战场。拆下的限量零件会回到本局仓库。' or table.concat(result.errors,'；')
        if last~=text then reason:SetText(text);last=text end;depart:SetDisabled(not result.ok);shop:SetText('整备商店 · ◆ '..D.Number(edit.controller.run.credits))
    end
    Update();return {root=panel,Update=Update}
end
function M.Shop(edit)
    if edit.shop then edit.shop:Close();edit.shop=nil;return end
    if edit.build.inventoryPanel then edit.build.inventoryPanel:Close() end
    edit.build.buildCamera:Release();local sw,sh=UI.GetViewportSize();local width=math.min(980,sw-48)
    local root=UI.GetRoot()
    local modal=W.Frame{position='absolute',left=(sw-width)/2,top=sh*.1,width=width,height=sh*.8,padding=20,gap=10,pointerEvents='auto'};edit.shop=modal
    modal.open=true
    modal.IsOpen=function(self) return self.open end
    modal.Close=function(self)
        if not self.open then return end;self.open=false
        edit.shop=nil;root:RemoveChild(self);self:Destroy()
    end
    local header=UI.Panel{width='100%',height=32,flexDirection='row',alignItems='center',gap=12};modal:AddChild(header)
    header:AddChild(UI.Label{text='整备商店 · 零件图纸',fontFamily='vox-title',fontSize=18,color='#e0f3fa',flexGrow=1})
    header:AddChild(UI.Label{text='◆ '..D.Number(edit.controller.run.credits),fontFamily='vox-title',fontSize=16,color='#ffc21a'})
    header:AddChild(W.Button{text='关闭 Esc',width=100,height=32,onClick=function() modal:Close() end})
    local bodyWidth=width-40
    local columns=math.max(1,math.floor((bodyWidth+6)/216))
    local cardWidth=(bodyWidth-6*(columns-1))/columns
    local body=UI.Panel{width=bodyWidth,gap=6};modal:AddChild(UI.ScrollView{width=bodyWidth,height=math.max(80,sh*.8-82),scrollY=true,children={body}})
    body:AddChild(UI.Label{text='买一张图纸，本局仓库多一件，马上能装。T1–T5 都能买，越高阶越贵。',fontFamily='vox-title',fontSize=14,color='#9fb6c4',height=28})
    for _,cat in ipairs({{'weapon','武器'},{'movement','移动'},{'function','功能'}}) do
        body:AddChild(UI.Label{text=cat[2],fontFamily='vox-title',fontSize=14,color='#8fd8ff',height=24});local grid=UI.Panel{width='100%',flexDirection='row',flexWrap='wrap',gap=6};body:AddChild(grid)
        local parts={};for _,p in ipairs(Defs.LIST) do if p.cat==cat[1] and not p.hidden then parts[#parts+1]=p end end
        table.sort(parts,function(a,b) local ta,tb=Inv.Tier(a.id),Inv.Tier(b.id);return ta==tb and Inv.Price(a.id)<Inv.Price(b.id) or ta<tb end)
        for _,p in ipairs(parts) do local id=p.id;local button=W.Button{text=p.name,shop=true,thumb=VoxTheme.Thumbnail(id),subtitle='◆ '..Inv.Price(id)..' · 仓库 '..(edit.controller.run.inventory[id] or 0),width=cardWidth,height=74,disabled=edit.controller.run.credits<Inv.Price(id)}
            button.props.onClick=function() local result=edit:Buy(id);if result.ok then edit.build:Notify('买到 '..p.name..' · 剩 ◆ '..D.Number(edit.controller.run.credits),'ok');modal:Close();edit.shop=nil;M.Shop(edit) else edit.build:Notify(result.reason,'bad') end end;grid:AddChild(button)
        end
    end
    root:AddChild(modal);return modal
end
return M
