local UI=require('urhox-libs/UI')
local Host=require('ui.DialogHost')
local Button=require('ui.SourceButton')
local Draw=require('ui.SourceDraw')
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Stash=require('salvage.StashRules')
local M={}
local Credit=UI.Panel:Extend('VoxPurchaseCredit')
function Credit:Render(vg)
    Draw.Begin(vg);local r=self:GetAbsoluteLayout();require('ui.SalvagePaint').Credit(vg,r.x,r.y+(r.h-16)/2,16)
    Draw.Text(vg,Draw.Number(self.props.value),r.x+20,r.y+(r.h-19)/2,19,nil,'vox-tabular')
end
local Tag=UI.Panel:Extend('VoxPurchaseTag')
function Tag:Render(vg)
    Draw.Begin(vg);local r=self:GetAbsoluteLayout();Draw.Icon(vg,self.props.icon,r.x,r.y,16,{255,194,26,255})
    Draw.Text(vg,self.props.text,r.x+22,r.y,14,{255,194,26,255},'vox-body')
end
local function Open(owner,title,tag,icon)
    local modal=Host.Open(owner,'',nil,{width=580,fullScroll=true})
    local body=UI.Panel{width='100%',paddingHorizontal=28,paddingTop=26,paddingBottom=24,flexShrink=0}
    modal:AddContent(body);modal.salvageBody=body
    modal.AddContent=function(_,child) body:AddChild(child);return modal end
    modal:AddContent(Tag{text=tag,icon=icon,width='100%',height=20,marginBottom=6})
    modal:AddContent(UI.Label{text=title,fontFamily='vox-title',fontSize=30,color='#eef7ff',width='100%',height=utf8.len(title)>17 and 72 or 36,marginBottom=18})
    return modal
end
local function Finish(modal)
    local sw,sh=UI.GetViewportSize();local width=math.min(580,sw*.92);local body=modal.salvageBody
    YGNodeCalculateLayout(body.node,width,YGUndefined,YGDirectionLTR)
    local height=YGNodeLayoutGetHeight(body.node)
    modal.contentContainer_:RemoveChild(body)
    modal.contentContainer_:AddChild(UI.ScrollView{width='100%',height=math.min(height,sh*.86),sourceNaturalHeight=height,
        scrollY=true,scrollX=false,showScrollbar=true,bounces=false,children={body}})
end
local function Rows(modal,list,limit)
    local rows={};for id,n in pairs(list) do rows[#rows+1]={id=id,n=n,cost=Data.items[id].price*n} end
    table.sort(rows,function(a,b) return a.cost>b.cost end)
    local shown=math.min(limit or #rows,#rows);local total=0
    local content=UI.Panel{width='100%',flexShrink=0}
    local scroll=UI.ScrollView{width='100%',height=math.min(280,(shown+(shown<#rows and 1 or 0))*58),scrollY=true,marginBottom=16,children={content}};modal:AddContent(scroll)
    for i,row in ipairs(rows) do
        total=total+row.n
        if i<=shown then
            local item=Data.items[row.id];local type=row.id:sub(6)
            local line=UI.Panel{width='100%',height=58,flexDirection='row',alignItems='center',gap=14,borderTopWidth=1,borderColor={255,255,255,20},flexShrink=0}
            line:AddChild(UI.Panel{backgroundImage=require('ui.VoxTheme').Thumbnail(type),width=48,height=48,backgroundFit='contain'})
            line:AddChild(UI.Label{text=item.name,fontFamily='vox-body',fontSize=17,color='#eef7ff',flexGrow=1,flexShrink=1})
            line:AddChild(UI.Label{text=limit and ('×'..row.n) or ('缺 '..row.n..' 个'),fontFamily='vox-body',fontSize=14,color='#ffc21a',width=74})
            line:AddChild(Credit{value=limit and row.cost or item.price,width=110,height=32})
            content:AddChild(line)
        end
    end
    if #rows>shown then
        local restN,restCost=0,0;for i=shown+1,#rows do restN=restN+rows[i].n;restCost=restCost+rows[i].cost end
        local more=UI.Panel{width='100%',height=58,paddingLeft=62,flexDirection='row',alignItems='center',gap=14,flexShrink=0,borderTopWidth=1,borderColor={255,255,255,20}}
        more:AddChild(UI.Label{text='其余 '..(#rows-shown)..' 种零件',fontFamily='vox-body',fontSize=17,color='#c7d6e1',flexGrow=1})
        more:AddChild(UI.Label{text='×'..restN,fontFamily='vox-body',fontSize=14,color='#ffc21a',width=74})
        more:AddChild(Credit{value=restCost,width=110,height=32});content:AddChild(more)
    end
    return total,#rows
end
local function Actions(modal)
    local panel=UI.Panel{width='100%',flexDirection='row',justifyContent='flex-end',gap=8,marginTop=14,height=40}
    modal:AddContent(panel);return panel
end
function M.Parts(owner,short,retry,choose)
    local lobby=owner.app.salvageLobby;local list={}
    for type,n in pairs(short) do local id='part:'..type;if Data.items[id] then list[id]=n end end
    if next(list)==nil then return false end
    local first=next(list);local title=choose and ('购买「'..Data.items[first].name..'」') or '零件不够，补买以后接着装'
    local modal=Open(owner,title,'仓库里没有','warn');Rows(modal,list)
    local qty=1;local total=UI.Label{fontFamily='vox-body',fontSize=15,color='#c7d6e1',height=50,borderTopWidth=1,borderColor={255,255,255,20},paddingTop=14};modal:AddContent(total)
    local function Purchase()
        local items={};for id,n in pairs(list) do items[id]=n*qty end
        local result=lobby:BuyAll(items)
        if not result.ok then owner:Notify(result.reason,'bad');return end
        Host.Close(owner);owner:Notify('花了 '..Draw.Number(result.cost)..' 信用点','ok');if retry then retry() end
    end
    local actions=Actions(modal)
    actions:AddChild(Button{text='取消',sourceKind='dialog',width=90,height=40,onClick=function() Host.Close(owner) end})
    local buy=Button{text=choose and '购买' or '购买并装上',sourceKind='primary',width=154,height=40,onClick=Purchase};actions:AddChild(buy)
    local function Refresh()
        local cost=Stash.Price(list)*qty
        total:SetText('余额 ◆ '..Draw.Number(lobby.data.credits)..'     合计 ◆ '..Draw.Number(cost));buy:SetDisabled(cost>lobby.data.credits)
    end
    if choose then
        local row=UI.Panel{width='100%',height=42,flexDirection='row',gap=4,marginBottom=16};modal.salvageBody:InsertChild(row,#modal.salvageBody.children-1)
        local buttons={}
        for _,n in ipairs({1,5,10,20}) do local b=Button{text='×'..n,sourceKind=n==1 and 'primary' or 'dialog',flexGrow=1,height=42,onClick=function()
            qty=n;for k,button in pairs(buttons) do button.props.sourceKind=k==n and 'primary' or 'dialog' end;Refresh()
        end};buttons[n]=b;row:AddChild(b) end
    end
    Refresh();Finish(modal);return true
end
function M.Car(s,id)
    local app=s.app;local lobby=app.salvageLobby
    local bp=require('construction.Prefab').Create(require('construction.Blueprint').New(),id):ToTable()
    if not app.bays:FirstEmpty() then app.toasts:Push('打捞车位都满了，先在「车库」拆掉一辆','warn');return false end
    local need=Stash.Need(bp.parts);local missing={};local usage=lobby:Usage()
    for key,n in pairs(need) do local lack=n-lobby:Loose(key,usage);if lack>0 then missing[key]=lack end end
    local full,part=Stash.Price(need),Stash.Price(missing)
    local modal=Open(s,'购买「'..bp.name..'」','创意工坊','workshop');local total,kinds=Rows(modal,need,6)
    modal:AddContent(UI.Label{text='共 '..kinds..' 种 '..total..' 个零件 · 余额 ◆ '..Draw.Number(lobby.data.credits)..' · 整车 ◆ '..Draw.Number(full),fontFamily='vox-title',fontSize=15,color='#ffc21a',height=34,marginTop=12})
    local function Go(list)
        Host.Close(s)
        s.Run(function(discard)
            local previous=lobby.data;local purchased=lobby:BuyAll(list)
            if not purchased.ok then return false,purchased.reason end
            local called,ok,err,reason=pcall(app.bays.CreateVehicle,app.bays,id,nil,discard)
            if not called or not ok then
                -- A failed garage rollback may still contain the purchased car.
                -- Preserve its payment until that storage failure is resolved.
                if called and reason=='rollback' then return false,err,reason end
                lobby.data=previous;local restored,restoreError=lobby:Save()
                if not restored then return false,'购买回滚存档失败：'..tostring(restoreError) end
                return false,called and err or ok,reason
            end
            return true
        end,function()
            if s.salvage then require('ui.SalvagePage').Tab(s,'garage') end
            s.SetTab('salvage');s.revision=-1
        end,bp)
    end
    local row=Actions(modal);row:AddChild(Button{text='取消',sourceKind='dialog',width=64,height=40,onClick=function() Host.Close(s) end})
    if part<full then row:AddChild(Button{text='用仓库里的零件拼 · '..(part>0 and ('补 '..Draw.Number(part)) or '不用花钱'),sourceKind='dialog',flexGrow=1,flexShrink=1,height=40,disabled=part>lobby.data.credits,onClick=function() Go(missing) end}) end
    row:AddChild(Button{text='购买整车',sourceKind='primary',width=104,height=40,disabled=full>lobby.data.credits,onClick=function() Go(need) end})
    Finish(modal);return true
end
return M
