-- Final frozen salvage.css/new-ui-salvage.css; same coordinates and page flow.
local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Button=require 'ui.SalvageButton'
local Item=require 'ui.SalvageItem'
local Paint=require 'ui.SalvagePaint'
local Paragraph=require 'ui.SourceParagraph'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Rules=require('core.ResourceData').Read('UI/SalvageRules.json')
local marketRank={};for i,id in ipairs(Rules.marketOrder) do marketRank[id]=i end
local Theme=require 'ui.VoxTheme'
local M={}
local tabs={{'loadout','整备',86},{'ops','行动',86},{'market','商人',86},{'garage','车库',86},{'workshop','创意工坊',154}}
function M.Deploy(s) return s.app:EnterTrial('salvage') end
function M.Tab(s,id)
    local sv=s.salvage;if sv.tab=='workshop' then require('ui.Workshop').Leave(s) end
    sv.tab=id;sv.selected=false;sv.qty=1;s.revision=-1;s.app:HomeView('salvage')
end
function M.Toggle(s) s.salvage.stash=not s.salvage.stash;s.salvage.selected=false;s.revision=-1;s.app:HomeView('salvage') end
function M.Trade(s)
    local sv=s.salvage;if not sv.selected then return end
    local ok,err=s.app.salvageLobby:Trade(sv.selected,sv.qty,sv.market=='sell')
    if not ok then s.app.toasts:Push(err,'bad') end;s.revision=-1
end
function M.Key(s)
    local sv=s.salvage
    if sv.tab=='workshop' and require('ui.Workshop').Key(s) then return end
    if input:GetKeyPress(KEY_ESCAPE) then
        if sv.gearPop then sv.gearPop=false;s.revision=-1
        elseif sv.selected then sv.selected=false;s.revision=-1
        elseif sv.tab~='loadout' then M.Tab(s,'loadout')
        elseif sv.stash then M.Toggle(s) else s.SetLobby('arena') end
    elseif input:GetKeyPress(KEY_TAB) and sv.tab=='loadout' then M.Toggle(s)
    elseif input:GetKeyPress(KEY_RETURN) then
        if sv.tab=='market' then M.Trade(s) elseif sv.tab=='ops' then M.Tab(s,'loadout')
        elseif sv.tab=='loadout' then M.Deploy(s) end
    else
        for i,key in ipairs({KEY_1,KEY_2,KEY_3,KEY_4,KEY_5}) do if input:GetKeyPress(key) then M.Tab(s,tabs[i][1]);return end end
    end
end
function M.Leave(s)
    if s.salvagePreviews then s.salvagePreviews:Dispose();s.salvagePreviews=nil end
end
function M.Create(s)
    s.salvage=s.salvage or {tab='loadout',stash=false,category='all',shopCategory='part',selected=false,qty=1,market='buy',sort='rarity',query='',gear={}}
    local sv=s.salvage;sv.shopCategory=sv.shopCategory or 'part';sv.sort=sv.sort or 'rarity';sv.query=sv.query or '';sv.gear=sv.gear or {}
    local lobby=s.app.salvageLobby;local w,h=s.width,s.height
    M.Leave(s)
    local usage=lobby:Usage();sv.loose={};for id in pairs(Data.items) do sv.loose[id]=lobby:Loose(id,usage) end
    local nameSize=utf8.len(s.app.blueprint.name)>8 and 48 or utf8.len(s.app.blueprint.name)>5 and 60 or 72
    local sectionTop=150+nameSize*1.05+10+26+26
    local page=Paint.Page{position='absolute',width=w,height=h,pointerEvents='box-none'};page.owner=s;page.paragraph=Paragraph.New(18,30)
    local function Add(text,kind,x,y,bw,bh,fn,extra,parent)
        local p={text=text,kind=kind,position='absolute',left=x,top=y,width=bw,height=bh,onClick=fn}
        for k,v in pairs(extra or {}) do p[k]=v end
        local b=s.Track(Button(p));b.paragraph=Paragraph.New(14,21);(parent or page):AddChild(b);return b
    end
    local function Box(kind,x,y,bw,bh,props)
        local p={kind=kind,position='absolute',left=x,top=y,width=bw,height=bh,pointerEvents=kind=='deal' and 'auto' or 'box-none'};for k,v in pairs(props or {}) do p[k]=v end
        local b=Paint.Surface(p);b.owner=s;b.paragraph=Paragraph.New(15,24);page:AddChild(b);return b
    end
    local tx=295;for _,t in ipairs(tabs) do Add(t[2],'tab',tx,0,t[3],88,function() M.Tab(s,t[1]) end,{selected=sv.tab==t[1]});tx=tx+t[3]+16 end
    Add('','button',w-100,22,44,44,function() require('ui.PauseMenu').Open(s) end,{icon='gear'})
    if sv.tab~='market' and sv.tab~='workshop' then
        Add('竞技对战','mode',w-492,h-212,214,50,function() s.SetLobby('arena') end,{icon='battle',subtitle='3v3 / 4v4 匹配'})
        Add('打捞行动','mode',w-274,h-212,214,50,function() end,{icon='hook',subtitle='搜打撤 · 独立仓库',selected=true})
    end
    local function Tiles(parent,list,columns,x,y,cell,gap,height,showPrice,queryKey)
        local grid=UI.Panel{width=columns*(cell+gap)-gap,flexShrink=0}
        local function Fill()
        local old={table.unpack(grid.children)};grid:ClearChildren();for _,child in ipairs(old) do child:Destroy() end
        local query=queryKey and (sv[queryKey] or '') or '';local row,col,rows=0,0,0
        for _,it in ipairs(list) do if query=='' or it.name:find(query,1,true) then
            local span=(it.size or 1)>=2 and 2 or 1
            if col+span>columns then row=row+1;col=0 end
            local tile=s.Track(Item{text=it.name,item=it,price=showPrice and (sv.market=='sell' and math.max(1,math.floor(it.price*Rules.sellRate)) or it.price) or nil,count=(not showPrice or sv.market=='sell') and sv.loose[it.id] or nil,selected=sv.selected==it.id,position='absolute',left=col*(cell+gap),top=row*(cell+gap),width=span*(cell+gap)-gap,height=cell,onClick=function() if sv.selected~=it.id then sv.qty=1 end;sv.selected=it.id;s.revision=-1 end})
            function tile:OnPointerDown(e)
                if e.button==MOUSEB_RIGHT and sv.tab=='market' then sv.qty=sv.selected==it.id and sv.qty+1 or 1;sv.selected=it.id;s.revision=-1;return true end
                return Item.OnPointerDown(self,e)
            end
            grid:AddChild(tile)
            rows=row+1;col=col+span;if col==columns then row=row+1;col=0 end
        end end
        grid:SetStyle({height=math.max(cell,rows*(cell+gap)-gap)})
        end
        Fill();parent:AddChild(UI.ScrollView{position='absolute',left=x,top=y,width=columns*(cell+gap)-gap+12,height=height,scrollY=true,scrollX=false,showScrollbar=false,bounces=false,children={grid}})
        return Fill
    end
    if sv.tab=='ops' then
        for i,op in ipairs(Data.ops) do Add(op.name,'operation',56,174+(i-1)*103,380,99,function() lobby.data.op=i;lobby:Save();s.revision=-1 end,{subtitle=op.en,description=op.desc,selected=(lobby.data.op or 1)==i,disabled=Paint.Value(s)<op.minValue,stripe=({D.orange,{255,194,26,255},{255,77,66,255}})[i]}) end
        Box('legend',56,501,380,225);Box('opcard',w-496,108,440,660)
        Add('整备','primary',w-496,h-150,440,80,function() M.Tab(s,'loadout') end,{subtitle='选好车和道具再出发',key='Enter'})
    elseif sv.tab=='workshop' then page:AddChild(require('ui.Workshop').Create(s))
    elseif sv.tab=='garage' then
        local slots=s.app.bays:Slots();local used=0;for _,data in ipairs(slots) do if data then used=used+1 end end
        local strip=UI.Panel{width=(used+1)*228-8,height=150,flexShrink=0,flexDirection='row',gap=8}
        local scroll=UI.ScrollView{position='absolute',left=56,top=h-270,width=w-636,height=150,scrollX=true,scrollY=false,children={strip}}
        s.salvagePreviews=require('ui.BayPreviews').New(scroll,s.app.previews)
        for i,data in ipairs(slots) do if data then
            local tile=s.Track(UI.Panel{width=220,height=150,flexShrink=0,backgroundColor='#18324d',onClick=function() s.Run(function(discard) return s.app.bays:Open(i,discard) end,nil,data) end})
            local picture=s.salvagePreviews:Add(data);picture:SetStyle({position='absolute',width=220,height=108});tile:AddChild(picture)
            tile:AddChild(Paint.Text{text=string.format('%02d  ',i)..data.name,fontSize=18,position='absolute',left=14,top=120,width=192,height=28});strip:AddChild(tile)
        end end
        strip:AddChild(Button{text='新建底盘',kind='slot',width=220,height=150,flexShrink=0,onClick=function()
            local data=require('construction.Prefab').Create(require('construction.Blueprint').New(),'empty'):ToTable()
            s.Run(function(discard) return s.app.bays:CreateVehicle('empty',nil,discard) end,nil,data)
        end})
        page:AddChild(scroll)
        Add('拆掉这辆车','ghost',w-234,h-270,178,44,function() local slot=s.app.bays.active;require('ui.GarageDialogs').Confirm(s,'拆掉这辆车？','零件退回仓库。',function() s.Run(function() return s.app.bays:Delete(slot) end,nil,s.app.bays:ReplacementAfterDelete(slot)) end) end,{icon='trash',disabled=used<=1 or not s.app.bays.active})
        Add('改装','primary',w-496,h-150,440,80,function() s.app:EnterBuild() end,{subtitle='零件优先用仓库里的',key='E'})
    elseif sv.tab=='loadout' then
        local sections=UI.Panel{width=456,height=600,flexShrink=0};local yy=0
        local counts,installed,seen={},{},{};for _,p in ipairs(s.app.blueprint:List()) do counts[p.type]=(counts[p.type] or 0)+1;if not seen[p.type] then seen[p.type]=true;installed[#installed+1]=p.type end end
        for _,cat in ipairs({'weapon','movement','function'}) do
            local list={};local total=0;for _,id in ipairs(installed) do local it=Data.items['part:'..id];if it and it.partCat==cat then list[#list+1]=it;total=total+counts[id] end end
            if cat~='function' or #list>0 then
            sections:AddChild(Paint.Text{text=({weapon='武器',movement='移动部件',['function']='功能部件'})[cat],position='absolute',left=0,top=yy,width=456,height=33,fontSize=20,rule=true})
            sections:AddChild(Paint.Text{text=tostring(total),position='absolute',right=0,top=yy,width=30,height=32,fontSize=18,font='vox-tabular',color=D.muted,alignRight=true});yy=yy+43
            for i,it in ipairs(list) do sections:AddChild(s.Track(Item{text=it.name,item=it,count=counts[it.part],compact=true,position='absolute',left=((i-1)%6)*76,top=yy+math.floor((i-1)/6)*76,width=72,height=72,onClick=function() s.app:EnterBuild() end})) end
            for i=#list+1,math.max(4,#list) do Add('','slot',((i-1)%6)*76,yy+math.floor((i-1)/6)*76,72,72,function() s.app:EnterBuild() end,nil,sections) end
            yy=yy+math.max(1,math.ceil(math.max(4,#list)/6))*76-4+18
            end
        end
        sections:AddChild(Paint.Text{text='货舱',position='absolute',left=0,top=yy,width=456,height=33,fontSize=20,rule=true})
        sections:AddChild(Paint.Text{text='20 格',position='absolute',right=0,top=yy,width=54,height=30,fontSize=18,font='vox-tabular',color=D.muted,alignRight=true});yy=yy+45
        sections:AddChild(Paint.Text{text='按格装：材料一格叠 20、其它叠 5，大件占 2 格；装得越重车越慢。撤离成功才带得回仓库。',position='absolute',left=0,top=yy,width=456,height=38.4,fontSize=12,paragraph=true,lineHeight=19.2});yy=yy+38.4+16
        sections:AddChild(Paint.Text{text='带入道具',position='absolute',left=0,top=yy,width=456,height=33,fontSize=20,rule=true});yy=yy+43
        sections:AddChild(Paint.Text{text=#sv.gear..' / 4',position='absolute',right=0,top=yy-43,width=54,height=30,fontSize=18,font='vox-tabular',color=D.muted,alignRight=true})
        for i=1,4 do
            local id=sv.gear[i]
            if id then sections:AddChild(s.Track(Item{text=Data.items[id].name,item=Data.items[id],count=sv.loose[id],compact=true,position='absolute',left=(i-1)*76,top=yy,width=72,height=72,onClick=function() table.remove(sv.gear,i);s.revision=-1 end}))
            else Add('','slot',(i-1)*76,yy,72,72,function() sv.gearPop=true;s.revision=-1 end,nil,sections) end
        end
        sections:SetStyle({height=yy+90});page:AddChild(UI.ScrollView{position='absolute',left=56,top=sectionTop,width=470,height=h-140-sectionTop,scrollY=true,scrollX=false,showScrollbar=false,children={sections}})
        Add('改装这辆车','button',56,h-122,214,52,function() s.app:EnterBuild() end,{icon='wrench',key='E'})
        local capacity,value,kinds=0,0,0;for id,n in pairs(sv.loose) do if n>0 then local it=Data.items[id];capacity=capacity+math.ceil(n/(Rules.stack[id] or 1));value=value+math.max(1,math.floor((it and it.price or 0)*Rules.sellRate))*n;kinds=kinds+1 end end
        local dx=sv.stash and w-580 or w
        Add('仓库','handle',dx-62,96+(h-324)/2-130,62,260,function() M.Toggle(s) end,{subtitle=tostring(kinds)})
        if sv.stash then
            Box('stash',dx,96,580,h-324,{capacity=capacity,value=value});Add('收起仓库','button',w-60,118,44,44,function() M.Toggle(s) end,{icon='close'})
            for i,cat in ipairs(Data.categories) do Add(cat.name,'category',dx+10+(i-1)*108,180,108,54,function() sv.category=cat.id;s.revision=-1 end,{selected=sv.category==cat.id}) end
            local list={};for _,it in pairs(Data.items) do if sv.loose[it.id]>0 and (sv.category=='all' or sv.category==it.cat) then list[#list+1]=it end end
            table.sort(list,function(a,b) if sv.sort=='count' then return sv.loose[a.id]>sv.loose[b.id] elseif sv.sort=='value' then return a.price*sv.loose[a.id]>b.price*sv.loose[b.id] else return a.rarity==b.rarity and a.price>b.price or a.rarity>b.rarity end end)
            local fill=Tiles(page,list,6,dx+22,300,84,6,h-580,false,'query')
            page:AddChild(require('ui.InventorySearch'){value=sv.query,placeholder='搜索物品',position='absolute',left=dx+22,top=248,width=240,height=38,onChange=function(_,q) sv.query=q;fill() end})
            for i,sort in ipairs({{'rarity','稀有度'},{'value','价值'},{'count','数量'}}) do Add(sort[2],'button',dx+274+(i-1)*92,248,92,38,function() sv.sort=sort[1];s.revision=-1 end,{selected=sv.sort==sort[1]}) end
            if sv.selected then Box('inspect',w-994,108,400,h-278) end
        end
        Add('出发','primary',w-496,h-150,440,80,function() M.Deploy(s) end,{subtitle='断坝峡谷 · '..Data.ops[lobby.data.op or 1].name..' · 带入价值 '..D.Number(Paint.Value(s)),key='Enter'})
        if sv.gearPop then
            local list={};for _,it in pairs(Data.items) do if it.cat=='gear' then local equipped=false;for _,id in ipairs(sv.gear) do if id==it.id then equipped=true end end;if not equipped then list[#list+1]=it end end end
            local rank={};for i,id in ipairs(Rules.itemOrder) do rank[id]=i end;table.sort(list,function(a,b) return rank[a.id]<rank[b.id] end)
            local ph=#list*68+12;Box('popup',56,math.max(262,262+yy-ph-8),360,ph)
            for i,it in ipairs(list) do Add(it.name,'gear',62,math.max(262,262+yy-ph-8)+6+(i-1)*68,348,68,function() if #sv.gear<4 then sv.gear[#sv.gear+1]=it.id end;sv.gearPop=false;s.revision=-1 end,{icon=it.icon,subtitle=lobby:Owned(it.id)>0 and ('仓库里 '..lobby:Owned(it.id)..' 个') or '仓库里没有，去商人那里买',disabled=lobby:Owned(it.id)<1}) end
        end
    elseif sv.tab=='market' then
        Add('后勤处 · 诺瓦','trader',56,108,210,64,function() end,{icon='shop',subtitle='收购 · 补给 · 改装件',selected=true})
        Add('黑市','trader',272,108,134,64,function() end,{icon='lock',subtitle='稀有零件',disabled=true});Add('改装师','trader',412,108,140,64,function() end,{icon='lock',subtitle='零件改造',disabled=true})
        Box('shelf',56,186,744,h-256);Box('deal',w-496,108,440,h-178)
        local categories=sv.market=='buy' and {{'part','零件'},{'material','材料'},{'gear','道具'}} or {{'all','全部'},{'part','零件'},{'material','材料'},{'cargo','货物'},{'gear','道具'}}
        for i,c in ipairs(categories) do Add(c[2],'subtab',78+(i-1)*72,186,68,54,function() sv.shopCategory=c[1];sv.selected=false;s.revision=-1 end,{selected=sv.shopCategory==c[1]}) end
        Add('购买','segment',w-470,128,194,48,function() sv.market='buy';if sv.shopCategory=='all' or sv.shopCategory=='cargo' then sv.shopCategory='part' end;sv.selected=false;s.revision=-1 end,{selected=sv.market=='buy'})
        Add('出售','segment',w-276,128,194,48,function() sv.market='sell';sv.selected=false;s.revision=-1 end,{selected=sv.market=='sell'})
        local list={};for _,id in ipairs(Rules.itemOrder) do local it=Data.items[id];local hidden=it.partCat=='structure' and (it.part:match('^glass%u') or it.part:match('^neon%u') or it.part:match('^conc%u') or it.part:match('^heavy%u') or it.part:find('Panel') or it.part:find('panel'));if (sv.shopCategory=='all' or it.cat==sv.shopCategory) and (sv.market=='buy' and not hidden or sv.market=='sell' and sv.loose[it.id]>0) then list[#list+1]=it end end
        table.sort(list,function(a,b) if sv.market=='sell' then return math.max(1,math.floor(a.price*Rules.sellRate))*sv.loose[a.id]>math.max(1,math.floor(b.price*Rules.sellRate))*sv.loose[b.id] end;return marketRank[a.id]<marketRank[b.id] end)
        local fill=Tiles(page,list,8,78,266,84,4,h-336,true,'shopQuery')
        page:AddChild(require('ui.InventorySearch'){value=sv.shopQuery or '',placeholder='搜索',solid=true,position='absolute',left=538,top=195,width=240,height=40,onChange=function(_,q) sv.shopQuery=q;fill() end})
        if sv.selected then
            sv.qty=math.min(sv.qty,lobby:MaxQuantity(sv.selected,sv.market=='sell'))
            local price=Data.items[sv.selected].price;if sv.market=='sell' then price=math.max(1,math.floor(price*.6)) end
            Add('-','quantity',w-470,h-332,52,52,function() sv.qty=math.max(1,sv.qty-1);s.revision=-1 end);Add(tostring(sv.qty),'quantity',w-414,h-332,200,52,function() end)
            Add('+','quantity',w-210,h-332,52,52,function() sv.qty=math.min(lobby:MaxQuantity(sv.selected,sv.market=='sell'),sv.qty+1);s.revision=-1 end)
            Add('最大','quantity',w-154,h-332,72,52,function() sv.qty=lobby:MaxQuantity(sv.selected,sv.market=='sell');s.revision=-1 end)
            Add(sv.market=='sell' and '出 售' or '购 买','primary',w-470,h-170,388,76,function() M.Trade(s) end,{subtitle=sv.market=='sell' and '换成信用点' or '放进仓库',key='Enter',disabled=sv.market=='buy' and price*sv.qty>lobby.data.credits})
        end
    end
    return page
end
return M
