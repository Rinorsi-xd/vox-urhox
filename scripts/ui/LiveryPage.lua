local UI=require 'urhox-libs/UI'
local Widgets=require 'ui.LiveryWidgets'
local Visual=require 'ui.LiveryVisual'
local Data=require 'construction.LiveryData'
local M={}
local function Place(widget,x,y,w,h) widget:SetStyle({position='absolute',left=x,top=y,width=w,height=h}) end
local function Clear(widget)
    local old={table.unpack(widget.children)};widget:ClearChildren();for _,c in ipairs(old) do c:Destroy() end
end
local function Button(s,parent,props,fn)
    props.position='absolute';props.padding=0;props.paddingHorizontal=0;props.paddingVertical=0;props.borderRadius=0;props.borderWidth=0;props.minWidth=0;props.minHeight=0;props.onClick=fn
    props.width=props.width or 1;props.height=props.height or 1
    local b=Widgets.Button(props);b.owner=s;parent:AddChild(b);return b
end
function M.Grid(s)
    Clear(s.gridBody);s.stickers={};local row,col=0,0;local width=(268-16)/3
    local paths={'Livery/custom-color.png','Livery/bar-undo.png','Livery/bar-redo.png','Livery/bar-clear.png','Livery/bar-done.png'}
    for _,st in ipairs(Data.Catalog().list) do if st.group==s.group then
        local b=Button(s,s.gridBody,{kind='sticker',text=st.name,sticker=st},function() s.session:Pick(s.session.pick==st.id and nil or st.id) end)
        Place(b,col*(width+8),row*(width+20.4+8),width,width+20.4);s.stickers[#s.stickers+1]=b;paths[#paths+1]=st.texture
        col=col+1;if col==3 then col=0;row=row+1 end
    end end
    s.gridBody:SetStyle({width=268,height=(row+(col>0 and 1 or 0))*(width+28.4)-8})
    s.gate:Start(paths,function(ok,err) if not s.active then return end;if not ok then s.app.toasts:Push(err,'bad') end end)
end
local function Props(s)
    local session=s.session;local d=session:List()[session.sel];local st=d and Data.Catalog().byId[d.s]
    local key=d and (session.sel..'|'..d.s..'|'..(st and st.kind or '')) or 'none'
    if key==s.propKey then return end;s.propKey=key
    for _,picker in ipairs(s.pickers or {}) do if picker.isOpen_ then picker:Close() end end
    Clear(s.propControls);s.pickers={};s.colorButtons={};s.sliders={};s.actions={}
    s.propHeight=d and 192+(st and st.kind=='shape' and #st.colors*85.46875 or 0) or 133.96875
    if not d then return end
    local y=64
    if st and st.kind=='shape' then
        local side=(268-32)/9
        for channel=1,#st.colors do
            for i,c in ipairs(require('Config').PALETTE) do
                local b=Button(s,s.propControls,{kind='swatch',channel=channel,hex=c.hex,text='',tooltip=c.name},function() session:Edit(function(q) q.c[channel]=c.hex end,true) end)
                Place(b,((i-1)%9)*(side+4),y+17+math.floor((i-1)/9)*(side+4),side,side);s.colorButtons[#s.colorButtons+1]=b
            end
            local hex=d.c[channel]
            local picker=Visual.Picker{position='absolute',value={r=(hex>>16)&255,g=(hex>>8)&255,b=hex&255},borderRadius=0,showAlpha=false,showPresets=false,pickerSize=180,
                onChange=function(_,v) session:Edit(function(q) q.c[channel]=v.r*65536+v.g*256+v.b end,true) end}
            picker.owner=s;picker.channel=channel;s.propControls:AddChild(picker);s.pickers[#s.pickers+1]=picker
            Place(picker,7*(side+4),y+17+side+4,side,side);y=y+85.46875
        end
    end
    local function Slider(id,min,max,step,value,fn)
        local slider=Widgets.Slider{position='absolute',min=min,max=max,step=step,value=value,onChange=function(_,v) session:Edit(fn(v),'soon') end,onChangeEnd=function() session:Record() end}
        s.propControls:AddChild(slider);s.sliders[id]=slider;Place(slider,42,y,166,18);y=y+30
    end
    Slider('size',1,30,.25,d.w,function(v) return function(q) q.w=v end end)
    Slider('rotation',-180,180,1,math.deg(d.r),function(v) return function(q) q.r=math.rad(v) end end)
    local actions={{'flip','flip','翻转',function() session:Edit(function(q) q.f=q.f and q.f~=0 and 0 or 1 end,true) end},
        {'mirror','mirror','左右对称',function() session:Mirror() end},{'duplicate','copy','复制',function() session:Duplicate() end},
        {'up','layerUp','上移',function() session:MoveLayer(1) end},{'down','layerDown','下移',function() session:MoveLayer(-1) end},{'delete','trash','撕掉',function() session:Remove() end}}
    for i,a in ipairs(actions) do local b=Button(s,s.propControls,{kind='action',action=a[1],icon=a[2],text=a[3]},a[4]);s.actions[a[1]]=b;Place(b,((i-1)%3)*(272/3),y+math.floor((i-1)/3)*36,260/3,32) end
end
function M.Layout(s)
    local w,h=UI.GetViewportSize();s.width=w;s.height=h
    Place(s.root,0,0,w,h);Place(s.surface,0,0,w,h)
    Place(s.lib,28,84,304,h-180);Place(s.props,w-328,84,300,h-180)
    local groupWidth=266/3;for i,b in ipairs(s.groups) do Place(b,16+(i-1)*(groupWidth+3),47,groupWidth,41.5) end
    Place(s.grid,16,100.5,272,h-323.296875)
    Place(s.propControls,16,47,268,s.propHeight)
    Place(s.layers,16,47+s.propHeight+49,268,math.max(60,h-110-(84+47+s.propHeight+49)))
    for i,b in ipairs(s.barButtons) do local a=({{0,102},{106,102},{212,136},{352,168}})[i];Place(b,w/2-260+a[1],h-74,a[2],46) end
    Place(s.hint,0,h-120.6875,w,32.6875)
end
function M.Create(owner)
    local s={owner=owner,app=owner.app,active=true,group='角色',groups={},barButtons={},revision=-1,propHeight=133.96875,thumbnails=require('ui.LiveryThumbnails').New(),gate=require('app.ResourceGate').New()}
    s.session=require('construction.LiverySession').New(s.app,require('audio.UiSound').Play);s.controls=require('controls.LiveryControls').New(s.session);owner.livery=s
    s.root=UI.Panel{position='absolute',width='100%',height='100%',pointerEvents='box-none'};s.root.session=s.session
    s.surface=Widgets.Surface{position='absolute',width='100%',height='100%'};s.surface.owner=s;s.root:AddChild(s.surface)
    s.lib=Visual.Panel{position='absolute',side='left'};s.lib.owner=s;s.root:AddChild(s.lib)
    s.props=Visual.Panel{position='absolute',side='right'};s.props.owner=s;s.root:AddChild(s.props)
    for _,group in ipairs({{'角色','CHARACTER'},{'图形','GRAPHIC'},{'文字','LETTERING'}}) do
        local b=Button(s,s.lib,{kind='group',group=group[1],text=group[1],english=group[2]},function() s.group=group[1];M.Grid(s) end);s.groups[#s.groups+1]=b
    end
    s.gridBody=UI.Panel{width=268,height=0,pointerEvents='box-none'}
    s.grid=UI.ScrollView{position='absolute',scrollX=false,scrollY=true,bounces=false,showScrollbar=false,children={s.gridBody}};s.lib:AddChild(s.grid)
    s.propControls=UI.Panel{position='absolute',pointerEvents='box-none'};s.props:AddChild(s.propControls)
    s.layerBody=UI.Panel{width=268,height=0,pointerEvents='box-none'}
    s.layers=UI.ScrollView{position='absolute',scrollX=false,scrollY=true,bounces=false,showScrollbar=false,children={s.layerBody}};s.props:AddChild(s.layers)
    for _,a in ipairs({{'undo','undo','撤销',function() s.session:Undo() end},{'redo','redo','重做',function() s.session:Undo(true) end},
        {'clear','trash','全部撕掉',function() s.session:Clear() end},{'done','check','完成',function() owner.SetTab('hangar') end}}) do
        s.barButtons[#s.barButtons+1]=Button(s,s.root,{kind='bar',action=a[1],icon=a[2],text=a[3]},a[4])
    end
    s.hint=Visual.Hint{position='absolute',pointerEvents='none'};s.hint.owner=s;s.root:AddChild(s.hint)
    M.Grid(s);M.Refresh(s);M.Layout(s);return s.root
end
function M.Refresh(s)
    Props(s);local session=s.session
    local key={};for _,d in ipairs(session:List()) do key[#key+1]=d.s end;key=table.concat(key,'|')
    if key~=s.layersKey then
        s.layersKey=key;Clear(s.layerBody);s.layerButtons={}
        for i=#session:List(),1,-1 do
            local b=Button(s,s.layerBody,{kind='layer',index=i,text=Data.Catalog().byId[session:List()[i].s] and Data.Catalog().byId[session:List()[i].s].name or session:List()[i].s},function() session:Select(i) end)
            Place(b,0,(#session:List()-i)*39,268,36);s.layerButtons[#s.layerButtons+1]=b
        end;s.layerBody:SetHeight(#session:List()*39)
    end
    local d=session:List()[session.sel]
    if d and s.sliders.size then
        if not s.sliders.size.state.isDragging then s.sliders.size.props.value=d.w end
        if not s.sliders.rotation.state.isDragging then s.sliders.rotation.props.value=(math.deg(d.r)+540)%360-180 end
    end
    s.barButtons[1]:SetDisabled(session.hi<=1);s.barButtons[2]:SetDisabled(session.hi>=#session.history);s.barButtons[3]:SetDisabled(#session:List()==0)
    M.Layout(s);s.revision=session.revision
end
function M.Update(owner,dt)
    local s=owner.livery;if not s or not s.active then return end
    if s.revision~=s.session.revision or s.width~=owner.width or s.height~=owner.height then M.Refresh(s) end
end
function M.Leave(owner)
    local s=owner.livery;if not s then return end;s.active=false;s.controls:Cancel();s.session:Dispose();s.gate:Cancel()
    for _,picker in ipairs(s.pickers or {}) do if picker.isOpen_ then picker:Close() end end
    s.thumbnails:Dispose();local images=require('urhox-libs/UI/Core/ImageCache')
    for _,st in ipairs(Data.Catalog().list) do images.Release(st.texture);cache:ReleaseResource('Image',st.texture,false) end
    for _,name in ipairs({'custom-color','bar-undo','bar-redo','bar-clear','bar-done'}) do images.Release('Livery/'..name..'.png');cache:ReleaseResource('Image','Livery/'..name..'.png',false) end
    owner.livery=nil
end
return M
