-- shared/build/editor.js hover content and #hoverInfo CSS in the UI-owned VG frame.
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Rich=require 'ui.SourceRichText'
local Defs=require('parts.Defs').PARTS
local Hover=Panel:Extend('VoxBuildHover')
local red={255,59,48,255}
function Hover:Sync()
    local s=self.session;local e=s.editor;local c=s.controls;local fly=s.buildCamera;local p=c.pointer
    local drag=p and (p.kind=='right' or p.kind=='middle' or p.orbit or p.select)
    if s.dialog or s.inventoryPanel or s.hud.colorOpen or not c.inside or fly.mode=='fp' and not fly.captured or fly.mode=='orbit' and drag or not e.hit and not e.stretch then self.info=nil;return end
    local target=e.hit and e.hit.partId and e.bp.parts[e.hit.partId];local pv=e.preview;local bad=false;local paragraphs={};local title={}
    local function Run(text,bold,muted) title[#title+1]={text=text,bold=bold,muted=muted} end
    local selectionSub
    if e.stretch then
        local stretch=e.stretch;bad=stretch.bad~=false
        if stretch.phase=='selection' then
            Run('选区拉伸 '..stretch.h..' 层 · 新增 '..#stretch.items..' 格',true)
            selectionSub=stretch.bad or '滚轮调层数 · 左键确认 · 右键 / Esc 取消 · 保留形状与配色'
        else
            local lo,hi=stretch.lo,stretch.hi
            Run((hi[1]-lo[1]+1)..' × '..(hi[3]-lo[3]+1)..' × '..(hi[2]-lo[2]+1),true)
            Run(' = '..#stretch.cells..' 格 '..Defs[stretch.type].name)
            if #stretch.mirrorCells>0 then Run(' （含镜像）',false,true) end
            selectionSub=stretch.bad and '放不下：'..stretch.bad or stretch.phase=='rect' and '挪准星定长宽 · 左键定下 · 右键取消' or '准星瞄到哪个高度就拉到哪（滚轮微调）· 左键放下 · 右键回去改长宽'
        end
    elseif s.selecting and not e.pasting then
        local d=c.dragSelection
        if d and d.lo then
            Run('框选 ');Run((d.hi[1]-d.lo[1]+1)..' × '..(d.hi[2]-d.lo[2]+1)..' × '..(d.hi[3]-d.lo[3]+1),true)
            Run(' 格 · 新增 ');Run(tostring(#d.parts),true);Run(' 个')
            selectionSub='松开左键选上 · 已选 '..#e:Selected()..' 个'
        elseif target then
            local on=e.selection[target.id];Run(on and '已选中 ' or '选择 ');Run(Defs[target.type].name,true)
            selectionSub=on and '右键取消' or '左键点选，按住拖到另一块 = 框选'
            selectionSub=selectionSub..' · 已选 '..#e:Selected()..' 个'
        end
    elseif e.pasting and pv and pv.paste then
        bad=not pv.ok
        if bad then
            for _,item in ipairs(pv.paste) do if not item.res.ok then Run('无法粘贴：'..item.res.reason);break end end
        else Run('粘贴 ');Run(tostring(#pv.paste),true);Run(' 个零件') end
    elseif (e.tool=='paint' or e.tool=='erase') and target then
        bad=e.tool=='erase';Run(bad and '删除 ' or '涂装 ');Run(Defs[target.type].name,true)
        if #e:Targets(e.hit)>1 then Run(' （含镜像）',false,true) end
    elseif pv and pv.type then
        local def=Defs[pv.type];bad=not pv.res.ok
        if bad then Run('无法放置：'..pv.res.reason)
        else Run('放置 ');Run(def.name,true);if def.budget>0 then Run(' · '..def.budget..' 点') end
            if target then Run(' 贴在 '..Defs[target.type].name,false,true) end
        end
    end
    if #title>0 then
        for _,run in ipairs(title) do
            run.size=run.bold and 16 or 12.5;run.font=not run.bold and 'vox-body' or nil
            run.lineHeight=run.bold and 'normal' or 20
            run.color=run.muted and D.muted or bad and (run.bold and {255,138,122,255} or {255,208,203,255}) or D.white
        end
        paragraphs[#paragraphs+1]=title
    end
    if selectionSub then
        paragraphs[#paragraphs+1]={{text=selectionSub,size=12,font='vox-body',color=D.muted}}
    elseif target and not e.pasting then
        local def=Defs[target.type];local hex=target.color;local conn=s.inspection:Get().conn
        local sub={{swatch={hex>>16&255,hex>>8&255,hex&255,255}},
            {text=def.name..' · 耐久 '..def.hp..' · '..def.mass..' kg',size=12,font='vox-body',color=D.muted}}
        if conn.coreId and conn.floating[target.id] then sub[#sub+1]={text=' · 未连接核心',size=16,color=red} end
        paragraphs[#paragraphs+1]=sub
    end
    if #paragraphs==0 then self.info=nil;return end
    local key=cjson.encode(paragraphs)..tostring(bad)
    if self.contentKey~=key then self.contentKey=key;self.textLayout=nil end
    self.info={paragraphs=paragraphs,bad=bad,center=fly.mode=='fp',x=c.x+18,y=c.y+18}
end
function Hover:Update(dt)
    local target=self.info and 1 or 0;local alpha=self.alpha or 0
    self.alpha=target>alpha and math.min(target,alpha+dt/.1) or math.max(target,alpha-dt/.1)
end
function Hover:Render(vg)
    if not self.info then return end
    D.Begin(vg);local info=self.info
    if not self.textLayout then self.textLayout=Rich.Layout(vg,info.paragraphs,316,20,{size=12.5,font='vox-body'}) end
    local layout=self.textLayout;local w,h=layout.width+24,layout.height+14;local r=self:GetAbsoluteLayout()
    local x,y=info.center and (r.w-w)/2 or info.x,info.center and r.h/2+36 or info.y
    self.bounds={x=x,y=y,w=w,h=h}
    nvgSave(vg);nvgGlobalAlpha(vg,self.alpha or 0)
    nvgBeginPath(vg);nvgRect(vg,x-20,y-12,w+40,h+48)
    nvgFillPaint(vg,nvgBoxGradient(vg,x,y+8,w,h,0,20,nvgRGBA(0,0,0,115),nvgRGBA(0,0,0,0)));nvgFill(vg)
    D.Rect(vg,x,y,w,h,{14,15,18,240});D.Rect(vg,x,y,3,h,info.bad and red or D.orange)
    Rich.Draw(vg,layout,x+12,y+7,info.center);nvgRestore(vg)
end
return Hover
