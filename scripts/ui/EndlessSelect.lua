local UI=require('urhox-libs/UI')
local W=require('ui.EndlessWidgets')
local D=require('endless.Data')
local Inv=require('endless.Inventory')
local M={}
function M.Open(app,start,cancel)
    local prior=UI.GetRoot();local sw,sh=UI.GetViewportSize();local w=sw*.8;local rows={}
    for _,r in ipairs(D.starters) do rows[#rows+1]={name=r.name,source=r.source,subtitle='系统起步车 · 不占用车位',errors={}} end
    for i=1,20 do local source=app.store:LoadSlot(i);if source then local v=Inv.Validate(source,D.config.startTier,Inv.Count(source));rows[#rows+1]={name=source.name,source=source,subtitle='车位 '..i,errors=v.errors} end end
    local root=UI.Panel{width='100%',height='100%',backgroundColor={0,0,0,100},pointerEvents='auto'}
    local frame=W.Frame{position='absolute',left=sw*.1,top=sh*.05,width=w,maxHeight=sh*.8,padding=32,gap=8};root:AddChild(frame)
    frame:AddChild(UI.Label{text='无尽模式 · 选择战车',fontFamily='vox-title',fontSize=28,color='#eef7ff',height=36})
    frame:AddChild(UI.Label{text='守住基地，击退每波敌人；敌人每过一个 Boss 波升一阶。共有 3 条命。',fontFamily='vox-title',fontSize=14,color='#a8c3d4',height=24})
    local rowHeight=110;local grid=UI.Panel{width='100%',flexDirection='row',flexWrap='wrap',gap=16};local columns=3;local cardW=(w-64-32)/3
    local scroll=UI.ScrollView{width='100%',height=math.min(sh*.8-180,math.ceil(#rows/columns)*(rowHeight+16)),scrollY=true,children={grid}};frame:AddChild(scroll)
    local closed=false
    local function Close() if closed then return end;closed=true;if UI.GetRoot()==root then UI.SetRoot(prior) end;root:Destroy() end
    for _,row in ipairs(rows) do local choice=row
        grid:AddChild(W.Button{text=row.name,subtitle=row.subtitle,reason=table.concat(row.errors,' · ')~='' and table.concat(row.errors,' · ') or '可以出发',disabled=#row.errors>0,width=cardW,height=rowHeight,
            onClick=function() Close();start(choice.source,nil) end})
    end
    local actions=UI.Panel{flexDirection='row',gap=12,width='100%',height=44};frame:AddChild(actions)
    local saved=app.store:Read(D.config.runKey,require('endless.Records').Run)
    if saved then actions:AddChild(W.Button{text='继续上次进度',width=154,height=44,onClick=function() Close();start(saved.blueprint,saved) end}) end
    actions:AddChild(W.Button{text='返回机库',width=112,height=44,onClick=function() Close();if cancel then cancel() end end})
    UI.SetRoot(root);return {Close=Close,root=root,rows=rows}
end
return M
