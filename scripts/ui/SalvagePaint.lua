local SourceParagraph=require("ui.SourceParagraph")
local Defs=require("parts.Defs")

local UI=require 'urhox-libs/UI'
local D=require 'ui.SourceDraw'
local Data=require('core.ResourceData').Read('UI/Outgame.json')
local Theme=require 'ui.VoxTheme'
local Rules=require('core.ResourceData').Read('UI/SalvageRules.json')
local Page=UI.Panel:Extend('VoxSalvagePage')
local Surface=UI.Panel:Extend('VoxSalvageSurface')
local Text=UI.Panel:Extend('VoxSalvageText')
local M={Page=Page,Surface=Surface,Text=Text}
function Text:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.props
    if p.rule then D.Rect(vg,r.x,r.y+r.h-1,r.w,1,{127,164,194,46}) end
    if p.paragraph then self.paragraph=self.paragraph or SourceParagraph.New(p.fontSize,p.lineHeight);self.paragraph:Draw(vg,p.text,r.x,r.y,r.w,{173,196,216,255});return end
    D.Text(vg,p.text,r.x+(p.alignRight and r.w or 0),r.y,p.fontSize or 20,p.color,p.font,p.alignRight and NVG_ALIGN_RIGHT or nil)
end
local panel={20,43,67,255};local line={127,164,194,46}
function M.Value(s)
    local total=0;for _,p in ipairs(s.app.blueprint:List()) do local it=Data.items['part:'..p.type];if it then total=total+it.price end end;return total
end
function M.Credit(vg,x,y,size)
    nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,size/20,size/20)
    D.Path(vg,{10,1.8,17.2,6,17.2,14,10,18.2,2.8,14,2.8,6})
    nvgStrokeColor(vg,D.Color({255,194,26,255}));nvgStrokeWidth(vg,1.9);nvgStroke(vg)
    nvgBeginPath(vg);nvgArc(vg,9.991681,10,3.4,-.783673,.783673,NVG_CCW);nvgStroke(vg);nvgRestore(vg)
end
local function Wallet(vg,x,y,value,size) M.Credit(vg,x,y,size);D.Text(vg,D.Number(value),x+size+5,y,size,nil,'vox-tabular') end
local function Carline(vg,s,x,y)
    local st=s.app.blueprint:Stats()
    local hp=0;for _,p in ipairs(s.app.blueprint:List()) do hp=hp+Defs.PARTS[p.type].hp end
    D.Text(vg,'带入价值',x,y,16,D.muted,'vox-body');Wallet(vg,x+72,y-2,M.Value(s),20)
    D.Rect(vg,x+166,y,1,16,line);D.Text(vg,'耐久',x+182,y,16,D.muted,'vox-body');D.Text(vg,D.Number(hp),x+217,y-2,20,nil,'vox-tabular')
    D.Rect(vg,x+279,y,1,16,line);D.Text(vg,'极速',x+296,y,16,D.muted,'vox-body');D.Text(vg,st.topSpeed>0 and D.Number(st.topSpeed) or '—',x+331,y-2,20,nil,'vox-tabular');D.Text(vg,'km/h',x+362,y,16,D.muted,'vox-body')
end
function Page:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.owner;local sv=s.salvage;local x,y,w,h=r.x,r.y,r.w,r.h
    if sv.tab=='ops' then
        D.Rect(vg,x,y,w,h,{12,13,16,255})
        local sz=math.min(w*.46,h*.86);self:RenderBackgroundImage(vg,'UI/Salvage/operations.png',{x=x+(w-sz)/2,y=y+(h-sz)/2+32,w=sz,h=sz},'contain',nil)
    else
        local fades={{x,y,560,h,true,{12,13,16,225},{12,13,16,128}},{x+560,y,200,h,true,{12,13,16,128},{12,13,16,0}},{x+w-980,y,220,h,true,{12,13,16,0},{12,13,16,77}},{x+w-760,y,760,h,true,{12,13,16,77},{12,13,16,179}},{x,y,w,170,false,{12,13,16,204},{12,13,16,0}},{x,y+h-200,w,200,false,{12,13,16,0},{12,13,16,191}}}
        if sv.tab=='market' then fades={{x,y,820,h,true,{12,13,16,217},{12,13,16,153}},{x+820,y,180,h,true,{12,13,16,153},{12,13,16,0}},{x+w-640,y,640,h,true,{12,13,16,0},{12,13,16,179}},{x,y,w,200,false,{12,13,16,204},{12,13,16,0}}}
        elseif sv.tab=='garage' then fades={{x,y+h-520,w,160,false,{12,13,16,0},{12,13,16,102}},{x,y+h-360,w,360,false,{12,13,16,102},{12,13,16,230}},{x,y,w,170,false,{12,13,16,204},{12,13,16,0}}} end
        for _,a in ipairs(fades) do
            D.Path(vg,{a[1],a[2],a[1]+a[3],a[2],a[1]+a[3],a[2]+a[4],a[1],a[2]+a[4]});D.Gradient(vg,a[1],a[2],a[3],a[4],a[6],a[7],a[5])
        end
    end
    D.Panel(vg,x+56,y+23,42,42,14,{185,231,255,255},{185,231,255,255});D.Icon(vg,'hook',x+64,y+31,26,D.ink)
    D.Text(vg,'打捞行动',x+112,y+20,28);D.Text(vg,'SALVAGE OPS',x+112,y+58,12,D.muted,'vox-body');Wallet(vg,x+w-218,y+30,s.app.salvageLobby.data.credits,28)
    if sv.tab=='loadout' then
        D.Text(vg,'出击战车',x+56,y+128,16,D.muted,'vox-body')
        local name=s.app.blueprint.name;local length=utf8.len(name);local size=length>8 and 48 or length>5 and 60 or 72;while size>36 and D.Width(vg,name,size)>470 do size=size-2 end
        D.Text(vg,name,x+56,y+142,size);Carline(vg,s,x+56,y+150+size*1.05+18)
    elseif sv.tab=='garage' then D.Text(vg,'车库',x+56,y+h-435,16,D.muted,'vox-body');D.Text(vg,s.app.blueprint.name,x+56,y+h-405,48);D.Text(vg,(s.app.blueprint:Size()-1)..' 个零件',x+56,y+h-316,20);D.Text(vg,'带入价值',x+210,y+h-314,16,D.muted,'vox-body');Wallet(vg,x+290,y+h-316,M.Value(s),20)
    elseif sv.tab=='ops' then D.Text(vg,'行动等级 · 断坝峡谷',x+56,y+128,26)
    elseif sv.tab=='market' then
        D.Rect(vg,x+860,y+h-170,3,60,D.orange);self.paragraph:Draw(vg,'“零件、修车材料、带进图的道具都在这儿。账上有钱就行。”',x+879,y+h-167,420,D.white)
    end
    local hints=({loadout={{'Enter','出发'},{'Tab','仓库'},{'E','改装'},{'1–5','切换页面'},{'Esc','返回竞技'}},ops={{'Enter','去整备'},{'1–5','切换页面'},{'Esc','回整备'}},market={{'Enter','成交'},{'右键','选中并 +1'},{'滚轮','调整数量'},{'Esc','回整备'}},garage={{'E','改装'},{'1–5','切换页面'},{'Esc','回整备'}},workshop={{'Enter','看详情 / 购买'},{'← →','换一辆'},{'Esc','返回'}}})[sv.tab]
    if require('controls.TouchMode').Enabled() then hints={} end
    local hx=x+56;for _,hint in ipairs(hints or {}) do
        local kw=D.Width(vg,hint[1],14,'vox-code')+14;D.Rect(vg,hx,y+h-48,kw,22,{19,36,58,255});D.Text(vg,hint[1],hx+7,y+h-46,14,D.muted,'vox-code')
        D.Text(vg,hint[2],hx+kw+8,y+h-44,15,D.muted,'vox-body');hx=hx+kw+8+D.Width(vg,hint[2],15,'vox-body')+26
    end
end
function Surface:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local s=self.owner;local sv=s.salvage;local kind=self.props.kind;local x,y,w,h=r.x,r.y,r.w,r.h
    D.Rect(vg,x,y,w,h,panel)
    if kind=='opcard' then
        self:RenderBackgroundImage(vg,'UI/Salvage/site.jpg',{x=x,y=y,w=w,h=230},'cover',nil);D.Text(vg,'断坝峡谷',x+26,y+252,26)
        local yy=y+295;yy=yy+self.paragraph:Draw(vg,'大坝断了以后废弃的水电站、老城和一艘坠毁货运舰。外圈安全，越往坠舰区、涡轮机房、干湖沉船走越值钱，舰载保险库只在那几处。',x+26,yy,w-52,D.muted).height+16
        local op=Data.ops[s.app.salvageLobby.data.op or 1]
        for _,fact in ipairs({{'行动等级',op.name..' · 敌车血量 ×'..op.enemyHp},{'保险库',op.vaults..' 个 · 出红概率 '..math.floor(op.red*100)..'%'},{'带入价值',D.Number(M.Value(s))},{'时限','15:00'},{'物资点','20 处'},{'撤离点','6 个'}}) do
            D.Line(vg,x+26,yy,x+w-26,yy,line);D.Text(vg,fact[1],x+26,yy+11,16,D.muted,'vox-body');D.Text(vg,fact[2],x+w-26,yy+10,20,D.white,'vox-body',NVG_ALIGN_RIGHT);yy=yy+42
        end
    elseif kind=='legend' then
        for i,text in ipairs({'外圈 · 安全','中圈 · 争夺','核心 · 禁区','舰载保险库候选（按行动等级开 1~3 个）','物资点（圈越大越值钱）','撤离点','出发点'}) do
            D.Rect(vg,x+18,y+22+(i-1)*29,12,8,({{67,143,165,255},{146,124,53,255},{169,51,63,255},{255,194,26,255}})[math.min(i,4)]);D.Text(vg,text,x+50,y+18+(i-1)*29,14,D.muted,'vox-body')
        end
    elseif kind=='stash' then
        D.Rect(vg,x,y,84,84,{185,231,255,255});D.Icon(vg,'cube',x+24,y+24,36,D.ink);D.Text(vg,'仓库',x+102,y+14,30)
        D.Text(vg,D.Number(self.props.capacity)..' / '..Rules.cells..' 格',x+102,y+52,15,D.muted,'vox-tabular');D.Text(vg,'估值',x+w-94,y+15,13,D.muted,'vox-body',NVG_ALIGN_RIGHT)
        D.Text(vg,D.Number(self.props.value),x+w-94,y+41,24,nil,'vox-tabular',NVG_ALIGN_RIGHT);D.Line(vg,x,y+84,x+w,y+84,line)
    elseif kind=='shelf' then D.Line(vg,x,y+64,x+w,y+64,line)
    elseif kind=='deal' or kind=='inspect' then
        local it=Data.items[sv.selected]
        if not it then
            D.Icon(vg,'shop',x+w/2-20,y+413,40,D.muted);D.Text(vg,sv.market=='sell' and '选一件要卖的东西' or '选一件商品',x+w/2,y+455,22,D.muted,nil,NVG_ALIGN_CENTER)
            D.Text(vg,sv.market=='sell' and '只有没装在车上的零件才能卖' or '左键选中，右键选中并 +1',x+w/2,y+487,14,D.muted,'vox-body',NVG_ALIGN_CENTER)
        else
            local iy=kind=='deal' and y+88 or y+28;local size=kind=='deal' and 108 or 220;local ix=kind=='deal' and x+26 or x+(w-size)/2
            local rc=Data.rarity[it.rarity+1].color;local tint={tonumber(rc:sub(2,3),16),tonumber(rc:sub(4,5),16),tonumber(rc:sub(6,7),16),255}
            D.Rect(vg,ix,iy,size,size,{32,58,84,255});D.Rect(vg,ix,iy,size,3,tint)
            if it.part then self:RenderBackgroundImage(vg,Theme.Thumbnail(it.part),{x=ix+8,y=iy+8,w=size-16,h=size-16},'contain',nil) else D.Icon(vg,it.icon,ix+size/2-28,iy+size/2-28,56,D.orange) end
            local tx=kind=='deal' and ix+124 or x+28;local ty=kind=='deal' and iy+10 or iy+size+20
            local fs=34;while fs>16 and D.Width(vg,it.name,fs)>x+w-26-tx do fs=fs-1 end
            local category='';for _,cat in ipairs(Data.categories) do if cat.id==it.cat then category=cat.name end end
            D.Text(vg,Data.rarity[it.rarity+1].name..' · '..category,tx,ty,15,tint,'vox-body');D.Text(vg,it.name,tx,ty+24,fs)
            local description=self.paragraph:Draw(vg,it.desc,x+26,kind=='deal' and iy+122 or ty+86,w-52,D.muted)
            if kind=='deal' then
                local rowY=iy+122+description.height+14;local unit=sv.market=='sell' and math.max(1,math.floor(it.price*Rules.sellRate)) or it.price
                D.Line(vg,x+26,rowY,x+w-26,rowY,line);D.Text(vg,'单价',x+26,rowY+10,15,D.muted,'vox-body');Wallet(vg,x+w-26-D.Width(vg,D.Number(unit),19,'vox-tabular')-24,rowY+9,unit,19)
                D.Line(vg,x+26,rowY+38,x+w-26,rowY+38,line);D.Text(vg,'仓库里',x+26,rowY+48,15,D.muted,'vox-body');D.Text(vg,D.Number(sv.loose[it.id] or 0),x+w-26,rowY+47,19,nil,'vox-tabular',NVG_ALIGN_RIGHT)
                local total=unit*sv.qty;D.Line(vg,x+26,y+h-200,x+w-26,y+h-200,line);D.Text(vg,'合计',x+26,y+h-187,16,D.muted,'vox-body');Wallet(vg,x+w-26-D.Width(vg,D.Number(total),28,'vox-tabular')-35,y+h-192,total,28)
                D.Text(vg,'持有',x+26,y+h-139,16,D.muted,'vox-body');Wallet(vg,x+w-26-D.Width(vg,D.Number(s.app.salvageLobby.data.credits),20,'vox-tabular')-27,y+h-142,s.app.salvageLobby.data.credits,20)
                return
            end
            local loose=sv.loose[it.id] or 0;local used=math.max(0,s.app.salvageLobby:Owned(it.id)-loose)
            local facts={{'仓库里',D.Number(loose)}};if used>0 then facts[#facts+1]={'装在车上',D.Number(used)} end
            facts[#facts+1]={'占用',math.ceil(loose/(Rules.stack[it.id] or 1))..' 格 · 每格 '..(Rules.stack[it.id] or 1)}
            local unit=math.max(1,math.floor(it.price*Rules.sellRate));facts[#facts+1]={'收购价',D.Number(unit)}
            for i,fact in ipairs(facts) do local fy=y+h-140-(#facts-i+1)*38
                D.Line(vg,x+28,fy,x+w-28,fy,line);D.Text(vg,fact[1],x+28,fy+10,15,D.muted,'vox-body');D.Text(vg,fact[2],x+w-28,fy+9,19,nil,'vox-tabular',NVG_ALIGN_RIGHT)
            end
            Wallet(vg,x+w-28-D.Width(vg,D.Number(unit*sv.qty),19,'vox-tabular')-24,y+h-58,unit*sv.qty,19)
            return
        end
        D.Line(vg,x+26,y+h-72,x+w-26,y+h-72,line);D.Text(vg,'持有',x+26,y+h-56,16,D.muted,'vox-body')
        local amount=D.Number(s.app.salvageLobby.data.credits);local cashWidth=D.Width(vg,amount,28,'vox-tabular')+35;Wallet(vg,x+w-26-cashWidth,y+h-61,s.app.salvageLobby.data.credits,28)
    end
end
return M
