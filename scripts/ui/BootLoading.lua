-- Original #loading / .ld-core composition from the frozen H5 startup page.
local D=require 'ui.SourceDraw'
local M={}
local tips={
    '按 B 打开零件库，指着零件按 1–0 就能放进快捷栏',
    '按 M 开启镜像建造，左右两边一起搭',
    '按 T 一键试车，再按 T 回来接着改',
    '右键删除零件，中键拿起对准的零件和它的颜色',
    '档位决定预算和质量上限：从 T1 新兵到 T5 传奇',
    '在机库主页点「新战车」，可以从零建造，也能放进预制车',
    '按 Esc 打开暂停菜单，画质和泛光都在画面设置里',
    '按 J 拉伸：点起点、点长宽、点高度，一次拉出一大片方块；Q 选中按 F 转成没有接缝的连续块',
    'Q 选块，F 连成整体；J 点选区表面批量拉伸，滚轮调层数',
    'Q 选择时，左键按住从一块拖到另一块，松开就选中整个方框；镜像同步选择',
    'Alt+1–0 或 Alt+滚轮换颜色：新放的方块就是这个颜色；P 上色时按住 Alt 点一下，全车同色一起换',
}
local labels={download='正在加载机库与战车资源',resources='正在准备贴图',scene='正在搭建机库',
    prepare='正在准备战车',environment='正在烘焙环境光',activate='正在预热着色器'}
function M.Draw(page,vg,w,h)
    local flow=page.owner;local t=flow.elapsed
    local white=D.white;local muted=D.muted;local accent=D.orange
    D.Rect(vg,0,0,w,h,{10,11,13,255})
    nvgBeginPath(vg);nvgRect(vg,0,0,w,h)
    nvgFillPaint(vg,nvgRadialGradient(vg,w/2,h*.46,0,math.max(w,h)*.58,nvgRGBA(35,38,44,255),nvgRGBA(10,11,13,255)));nvgFill(vg)
    local x=(w-560)/2;local y=(h-340)/2
    local colors={accent,{255,255,255,71},white,{255,255,255,153}}
    nvgSave(vg);nvgTranslate(vg,w/2,y+36);nvgRotate(vg,math.pi/4);nvgScale(vg,.86,.86)
    for i=1,4 do
        local phase=(t-(i-1)*.2)%1.6/1.6
        local pulse=phase<.4 and (.5-.5*math.cos(phase/.4*math.pi)) or (.5+.5*math.cos((phase-.4)/.6*math.pi))
        local size=32.5*(.82+.18*pulse);local cx=i%2==1 and -19.75 or 19.75;local cy=i<=2 and -19.75 or 19.75
        local color=colors[i]
        D.Rect(vg,cx-size/2,cy-size/2,size,size,{color[1],color[2],color[3],math.floor(color[4]*(.35+.65*pulse))})
    end
    nvgRestore(vg)
    D.Text(vg,'构装纪元',w/2,y+102,76,white,'vox-title',NVG_ALIGN_CENTER,6)
    local row=y+234;local pct=math.floor(flow.progress*100+.5)
    local batch,total=flow:WarmupStatus();local shown=flow:DisplayProgress()
    D.Text(vg,flow.failed and '加载失败' or flow.progress==1 and '就绪' or labels[flow.steps[flow.current].id],x,row+20,13,muted,'vox-body')
    if batch then
        -- 着色器预热按批推进：显示批次比百分比更能说明还在动。
        D.Text(vg,batch..'/'..total,x+535,row,40,white,'vox-title',NVG_ALIGN_RIGHT)
    else
        D.Text(vg,tostring(pct),x+535,row,40,white,'vox-title',NVG_ALIGN_RIGHT)
        D.Text(vg,'%',x+537,row+16,20,muted,'vox-title')
    end
    for dx=0,552,12 do
        D.Rect(vg,x+dx,row+48,9,12,{255,255,255,20})
        local filled=math.min(9,math.floor(560*shown-dx))
        if filled>0 then D.Rect(vg,x+dx,row+48,filled,12,accent) end
    end
    D.Rect(vg,x,row+86,42,21,accent)
    D.Text(vg,'提示',x+21,row+88,14,D.ink,'vox-title',NVG_ALIGN_CENTER)
    local tip=tips[math.floor(t/2.6)%#tips+1]
    nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,t%2.6/.26));D.Text(vg,tip,x+54,row+89,13,muted,'vox-body');nvgRestore(vg)
    if flow.failed then
        D.Text(vg,flow.error,x,row+130,15,{255,138,128,255},'vox-body')
        page.backRect={x=w/2-60,y=row+166,w=120,h=38}
        D.Rect(vg,w/2-60,row+166,120,38,accent)
        D.Text(vg,'重试',w/2,row+175,18,{11,41,70,255},'vox-title',NVG_ALIGN_CENTER)
    end
end
return M
