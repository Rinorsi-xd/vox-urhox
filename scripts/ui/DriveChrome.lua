local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Draw=require 'ui.DriveDraw'
local Theme=require 'ui.VoxTheme'
local Chrome=Panel:Extend('VoxDriveChrome')
local keys={{'W'},{'S'},' 油门 · ',{'A'},{'D'},' 转向 · ',{'Q/E'},' 横移 · ',{'空格/Shift'},' 升降（松开定高） · ',{'X'},
    ' 关闭推进定高 · 悬浮调离地高度；节足空格跳跃、空中按住接推进；轮式车空格手刹 · 鼠标 瞄准 · 滚轮 远近 · 左键 开火 · 右键 开镜 · ',{'1-6'},' 换武器 · ',
    {'R'},' 翻正 · ',{'C'},' 镜头跟车 · ',{'N'},' 传送 · ',{'I'},' 详细数据 · ',{'Backspace'},' 全部复原'}
function Chrome:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local x,y,w,h=r.x,r.y,r.w,r.h;local s=self.session;local kind=self.props.kind
    if kind=='title' then
        local mapName=s.map and s.map.name or '试车场';local title=Draw.Width(vg,mapName,18,4);local name=Draw.Width(vg,s.name,15,1);w=3+32+title+12+name+1
        self.drawWidth=w;Draw.Panel(vg,x,y,w,37);D.Rect(vg,x,y,3,37,D.white)
        Draw.Text(vg,mapName,x+19,y+9,18,D.white,4);Draw.Text(vg,s.name,x+31+title,y+10,15,D.white,1)
    elseif kind=='exit' then
        Draw.Panel(vg,x,y,w,h,self.state.hovered and {86,93,104,255} or nil)
        if self.state.hovered then D.Rect(vg,x+1,y+1,w-2,h-2,{95,228,255,41}) end
        if self.props.course then Draw.Text(vg,self.props.text,x+w/2,y+10,14,D.white,1.5,nil,NVG_ALIGN_CENTER)
        elseif s.touch then D.Text(vg,'返回车库',x+w/2,y+15,17,D.white,nil,NVG_ALIGN_CENTER)
        else Draw.Text(vg,'返回车库',x+15,y+10,14,D.white,1.5);Draw.Key(vg,'T',x+w-33,y+8) end
    elseif kind=='stats' then
        Draw.Panel(vg,x,y,w,h)
        for i,item in ipairs({{'总伤害',s.world.stats.damage},{'秒伤',s.world.metrics.dps},{'击毁',s.world.stats.kills}}) do
            local cx=x+5+(i-1)*66+32
            if i>1 then D.Rect(vg,cx-32,y+5,1,h-10,{53,58,66,255}) end
            Draw.Text(vg,item[1],cx,y+7,11,D.muted,1,'vox-body',NVG_ALIGN_CENTER)
            D.Text(vg,tostring(math.floor(item[2]+.5)),cx,y+22,20,i==2 and D.orange or D.white,'vox-tabular',NVG_ALIGN_CENTER)
        end
    elseif kind=='weapon' then
        local g=self.group;local active=s.weapons.current==self.index
        nvgSave(vg);nvgGlobalAlpha(vg,active and 1 or .65);Draw.Panel(vg,x,y,w,h,active and D.white or nil)
        if active then D.Rect(vg,x,y,3,h,D.white) end
        if not g then D.Text(vg,'这辆车没有武器',x+w/2,y+14,14,D.muted,nil,NVG_ALIGN_CENTER)
        elseif s.touch then
            self:RenderBackgroundImage(vg,Theme.Thumbnail(g.weapons[#g.weapons].type),{x=x+5,y=y+4,w=32,h=32},'contain',nil)
            D.Text(vg,g.name,x+42,y+10,14,D.white)
            D.Text(vg,active and '已选中' or '点击切换',x+42,y+30,11,D.muted)
            D.Rect(vg,x+1,y+h-3,(w-2)*(self.readiness or 0),2,D.white)
        else
            Draw.Key(vg,tostring(self.index),x+7,y+13.5)
            self:RenderBackgroundImage(vg,Theme.Thumbnail(g.weapons[#g.weapons].type),{x=x+33,y=y+4,w=38,h=38},'contain',nil)
            Draw.Text(vg,g.name..(#g.weapons>1 and ' ×'..#g.weapons or ''),x+79,y+14.5,14,D.white,1)
            local output=g.output or 1;Draw.Text(vg,'火力 '..math.floor(output*100+.5)..'%',x+w-11,y+15.5,12,output<1 and D.muted or D.white,0,nil,NVG_ALIGN_RIGHT)
            D.Rect(vg,x+1,y+h-3,(w-2)*(self.readiness or 0),2,D.white)
        end
        nvgRestore(vg)
    elseif kind=='timer' then
        local elapsed=s.world.metrics:Timer(s.world.time);local last=s.world.metrics.timing.last
        if not elapsed and not last then return end
        local a=elapsed and string.format('100 米  %.2f 秒',elapsed) or ''
        local b=last and string.format('上次：%.2f 秒 · 末速 %.0f km/h',last.time,last.speed*3.6) or ''
        w=math.max(Draw.Width(vg,a,24,1,'vox-tabular'),Draw.Width(vg,b,13,1))+38;h=(a~='' and 29 or 0)+(b~='' and 16 or 0)+(a~='' and b~='' and 2 or 0)+14
        -- Source flex space-between leaves the timer between title and stats widths.
        local sw=require('urhox-libs/UI').GetViewportSize();x=(sw+(self.title.drawWidth or 149)-206-w)/2
        Draw.Panel(vg,x,y,w,h);local cy=y+7
        if a~='' then Draw.Text(vg,a,x+w/2,cy,24,D.white,1,'vox-tabular',NVG_ALIGN_CENTER);cy=cy+31 end
        if b~='' then Draw.Text(vg,b,x+w/2,cy,13,D.white,1,nil,NVG_ALIGN_CENTER) end
    elseif kind=='keys' then
        if not self.tokens then
            self.tokens={};self.total=30
            for _,key in ipairs(keys) do
                local width=type(key)=='table' and math.max(18,Draw.Width(vg,key[1],12,.5)+12)+2 or D.Width(vg,key,12,'vox-body')
                self.tokens[#self.tokens+1]={value=key,width=width};self.total=self.total+width
            end
        end
        w=self.total;x=(r.w-w)/2;Draw.Panel(vg,x,y,w,33);local cx=x+15
        for _,item in ipairs(self.tokens) do
            if type(item.value)=='table' then Draw.Key(vg,item.value[1],cx+1,y+7)
            else D.Text(vg,item.value,cx,y+9,12,D.muted,'vox-body') end
            cx=cx+item.width
        end
    elseif kind=='pause' then
        D.Rect(vg,x,y,w,h,{2,6,10,89});local text='点击画面继续驾驶';local bw=Draw.Width(vg,text,20,3)+62;local bx,by=(w-bw)/2,(h-90)/2
        self.box={x=bx,y=by,w=bw,h=90};Draw.Panel(vg,bx,by,bw,90,{86,93,104,255})
        Draw.Text(vg,text,w/2,by+19,20,D.white,3,nil,NVG_ALIGN_CENTER)
        D.Text(vg,'鼠标移动转视角 · 滚轮调远近 · Esc 释放鼠标',w/2,by+100,13,D.white,'vox-body',NVG_ALIGN_CENTER)
        D.Text(vg,'未接管鼠标时，也可按住右键拖动视角',w/2,by+122,13,D.muted,'vox-body',NVG_ALIGN_CENTER)
        local kw=math.max(18,Draw.Width(vg,'Esc',12,.5)+12);local a=D.Width(vg,' 或 ',13,'vox-body');local b=D.Width(vg,' 返回车库',13,'vox-body')
        local cx=(w-18-a-kw-b)/2;Draw.Key(vg,'T',cx,by+52);cx=cx+18
        D.Text(vg,' 或 ',cx,by+54,13,D.muted,'vox-body');cx=cx+a;Draw.Key(vg,'Esc',cx,by+52);D.Text(vg,' 返回车库',cx+kw,by+54,13,D.muted,'vox-body')
    end
end
return Chrome
