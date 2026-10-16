local DialogHost=require("ui.DialogHost")
local SourceButtonMotion=require("ui.SourceButtonMotion")

local UI=require 'urhox-libs/UI';local Widgets=require 'ui.MusicWidgets';local Visual=require 'ui.MusicBoxVisual'
local Layout=require 'ui.MusicBoxLayout';local MD=require 'ui.MusicDraw'
local M={}
local FILTERS={{'all','全部'},{'favorites','收藏'},{'hangar','机库'},{'training','训练营'},{'drive-combat','战斗'},{'salvage','搜打撤'}}
function M.Tracks(s,includeSearch)
    local tracks={};local query=(s.query or ''):lower()
    for _,t in ipairs(s.player.catalog.tracks) do
        local allowed=s.filter=='all' or s.filter==t.group or s.filter=='favorites' and s.player.favorites[t.id]
        local text=(t.title..' '..t.english..' '..t.number..' '..t.description):lower()
        if allowed and (not includeSearch or query=='' or text:find(query,1,true)) then tracks[#tracks+1]=t end
    end
    return tracks
end
local function Button(s,parent,id,icon,fn,props)
    local p={icon=icon,text='',kind='icon',position='absolute',padding=0,borderWidth=0,minWidth=0,minHeight=0,borderRadius=0,onClick=function()
        s.keyboardFocus=false;if id~='mode' then s.modeMenu:SetVisible(false) end;fn()
    end}
    for k,v in pairs(props or {}) do p[k]=v end
    local b=Widgets.Button(p);b.owner=s;parent:AddChild(b)
    if id then s.buttons[id]=b end
    return b
end
function M.List(s)
    local focused=UI.GetFocus();local returnId=focused and focused.props.favorite
    local parent=focused;while parent do if parent==s.listBody then UI.ClearFocus();break end;parent=parent.parent end
    local old={table.unpack(s.listBody.children)};s.listBody:ClearChildren();for _,row in ipairs(old) do row:Destroy() end
    s.tracks=M.Tracks(s,true);s.rows={}
    for _,t in ipairs(s.tracks) do
        local row=Widgets.Row{width='100%',height=57*s.layout.k,flexShrink=0,flexDirection='row',alignItems='center',gap=0,padding=0,paddingLeft=2*s.layout.k,paddingBottom=s.layout.k,pointerEvents='box-none'}
        row.owner=s;row.track=t
        row.pick=Button(s,row,nil,nil,function() s.player:SetLibraryPlaylist(M.Tracks(s,false));s.player:PlayTrack(t.id) end,
            {text=t.title,kind='track',track=t,position='relative',width=0,flexGrow=1,flexShrink=1,height=56*s.layout.k})
        row.favorite=Button(s,row,nil,'heart',function() s.player:Favorite(t.id);if s.filter=='favorites' then M.List(s) end end,
            {kind='favorite',favorite=t.id,position='relative',width=30*s.layout.k,height=40*s.layout.k,flexShrink=0})
        s.rows[#s.rows+1]=row;s.listBody:AddChild(row)
        if returnId==t.id then UI.SetFocus(row.favorite) end
    end
    s.listBody:SetHeight(#s.tracks*57*s.layout.k);s.list:SetScroll(0,0)
    for _,b in ipairs(s.filters) do b.props.pressed=b.props.filter==s.filter end
end
local function Focus(s,widget)
    UI.SetFocus(widget)
    local _,y=s.list:GetScroll();local height=s.layout.rects.list[4]*s.layout.k
    for i,row in ipairs(s.rows) do if widget==row.pick or widget==row.favorite then
        local top=(i-1)*57*s.layout.k;local bottom=top+57*s.layout.k
        if top<y then s.list:SetScroll(0,top) elseif bottom>y+height then s.list:SetScroll(0,bottom-height) end
        break
    end end
end
function M.Open(owner)
    if owner.musicBox then return owner.musicBox end
    local player=owner.app.music;local s={owner=owner,player=player,filter='all',query='',buttons={},filters={},rows={},tracks={},alpha=0,time=0,pointers={}}
    s.previousFocus=UI.GetFocus();owner.CancelInput();DialogHost.Close(owner);owner.SetNew(false)
    player:SetLibraryPlaylist(player.catalog.tracks);player:SetLibraryMode(true);player:Unlock()
    s.root=UI.Panel{position='absolute',width='100%',height='100%',onPointerDown=function(_,e)
        if e.pointerId then s.pointers[e.pointerId]=e.pointerType end;s.keyboardFocus=false;return true
    end,onClick=function() s.modeMenu:SetVisible(false) end}
    s.frame=Visual.Frame{position='absolute',padding=0,pointerEvents='box-none'};s.frame.owner=s;s.root:AddChild(s.frame)
    s.modeMenu=Visual.Menu{position='absolute',padding=6,visible=false};s.modeMenu.owner=s
    Button(s,s.frame,'close','close',function() M.Close(owner) end)
    Button(s,s.frame,'favorite','heart',function() player:Favorite((player:Track() or player.catalog.tracks[1]).id);if s.filter=='favorites' then M.List(s) end end)
    local function Scroll(direction)
        local _,y=s.list:GetScroll();s.list:SetScroll(0,y+direction*s.layout.rects.list[4]*s.layout.k*.8)
    end
    Button(s,s.frame,'up','back',function() Scroll(-1) end,{kind='scroll',rotate=math.pi/2})
    Button(s,s.frame,'down','chev',function() Scroll(1) end,{kind='scroll'})
    Button(s,s.frame,'mode','shuffle',function() s.modeMenu:SetVisible(not s.modeMenu:IsVisible());if s.modeMenu:IsVisible() then UI.SetFocus(s.options[1]) end end,{pressed=true})
    Button(s,s.frame,'previous','skipBack',function() player:Resume();player:Previous() end)
    Button(s,s.frame,'play','pause',function() if player:CanPlay() then player:SetPaused(true) else player:Resume() end end,{kind='play'})
    Button(s,s.frame,'next','skipForward',function() player:Resume();player:Next() end)
    Button(s,s.frame,'queue','list',function()
        s.filter='all';s.query='';s.search:SetValue('');M.List(s)
        local current=player:Track()
        for i,t in ipairs(s.tracks) do if current and current.id==t.id then s.list:SetScroll(0,math.max(0,(i-.5)*57*s.layout.k-s.layout.rects.list[4]*s.layout.k/2));break end end
    end)
    Button(s,s.frame,'mute','volume',function()
        if not player.enabled then player:Resume() else player:SetVolume(player.volume>0 and 0 or player.lastVolume) end
    end)
    s.listBody=UI.Panel{width='100%',gap=0,padding=0,pointerEvents='box-none'}
    s.list=UI.ScrollView{position='absolute',scrollX=false,scrollY=true,bounces=false,showScrollbar=false,padding=0,children={s.listBody}};s.frame:AddChild(s.list)
    s.search=Widgets.Field{position='absolute',maxLength=80,value='',padding=0,onChange=function(_,text)
        s.query=text:match('^%s*(.-)%s*$');M.List(s)
    end};s.search.owner=s;s.frame:AddChild(s.search)
    s.seek=Widgets.Slider{position='absolute',value=0,min=0,max=1,step=.1,progress=true,onChangeEnd=function(_,v) player:Seek(v) end};s.seek.owner=s;s.frame:AddChild(s.seek)
    s.volume=Widgets.Slider{position='absolute',value=player.volume*100,min=0,max=100,step=1,onChange=function(_,v) player:SetVolume(v/100) end};s.volume.owner=s;s.frame:AddChild(s.volume)
    for _,widget in ipairs({s.search,s.seek,s.volume,s.list}) do
        local down,up,cancel=widget.OnPointerDown,widget.OnPointerUp,widget.OnPointerCancel
        widget.OnPointerDown=function(self,e) if e.pointerId then s.pointers[e.pointerId]=e.pointerType end;s.keyboardFocus=false;return down(self,e) end
        widget.OnPointerUp=function(self,e) if e.pointerId then s.pointers[e.pointerId]=nil end;return up(self,e) end
        widget.OnPointerCancel=function(self,e) if e.pointerId then s.pointers[e.pointerId]=nil end;return cancel(self,e) end
    end
    for _,f in ipairs(FILTERS) do
        s.filters[#s.filters+1]=Button(s,s.frame,nil,nil,function() s.filter=f[1];M.List(s) end,{kind='filter',text=f[2],filter=f[1]})
    end
    s.options={}
    for i,item in ipairs({{'shuffle','shuffle','随机播放'},{'sequence','list','顺序播放'},{'repeat','repeat','单曲循环'}}) do
        s.options[i]=Button(s,s.modeMenu,nil,item[2],function() player:SetPlayMode(item[1]);s.modeMenu:SetVisible(false);UI.SetFocus(s.buttons.mode) end,
            {kind='option',text=item[3],mode=item[1],left=7,top=7+(i-1)*42,width=146,height=42})
    end
    s.frame:AddChild(s.modeMenu);Layout.Apply(s);M.List(s)
    owner.musicBox=s;owner.root:AddChild(s.root);UI.PushOverlay(s.root);UI.SetFocus(s.buttons.play)
    return s
end
function M.Close(owner)
    local s=owner.musicBox;if not s then return end
    for id,kind in pairs(s.pointers) do UI.CancelPointer(id,kind) end
    local focus=UI.GetFocus();while focus do if focus==s.root then UI.ClearFocus();break end;focus=focus.parent end
    UI.PopOverlay(s.root);owner.root:RemoveChild(s.root);s.root:Destroy();owner.musicBox=nil
    s.player:SetLibraryMode(false)
    if s.previousFocus and s.previousFocus.node then UI.SetFocus(s.previousFocus) end
end
function M.Update(owner,dt)
    local s=owner.musicBox;if not s then return end
    local cw=graphics:GetWidth()/graphics:GetDPR();local ch=graphics:GetHeight()/graphics:GetDPR()
    if cw~=s.cssWidth or ch~=s.cssHeight then Layout.Apply(s) end
    s.time=math.min(.2,s.time+dt);s.alpha=SourceButtonMotion.Ease(s.time/.2,'css-ease-out')
    local p=s.player;local current=p:Track()
    s.buttons.play.props.icon=p:CanPlay() and 'pause' or 'play';s.buttons.mode.props.icon=p.playMode=='sequence' and 'list' or p.playMode
    s.buttons.mute.props.icon=p.volume>0 and p.enabled and 'volume' or 'volumeOff'
    s.buttons.favorite.props.pressed=p.favorites[(current or p.catalog.tracks[1]).id] or false
    for _,row in ipairs(s.rows) do row.favorite.props.pressed=p.favorites[row.track.id] or false end
    for _,b in ipairs(s.options) do b.props.pressed=p.playMode==b.props.mode end
    if not s.volume.state.dragging then s.volume.props.value=p.volume*100 end
    s.seek.props.max=math.max(.01,p:Duration());s.seek.props.disabled=not current or p.pending~=nil
    if not s.seek.state.dragging then s.seek.props.value=p:Position() end
    local _,scroll=s.list:GetScroll();s.buttons.up:SetDisabled(scroll<1)
    s.buttons.down:SetDisabled(scroll+s.layout.rects.list[4]*s.layout.k>=#s.tracks*57*s.layout.k-1)
    if input:GetKeyPress(KEY_ESCAPE) then
        if s.modeMenu:IsVisible() then s.modeMenu:SetVisible(false);UI.SetFocus(s.buttons.mode) else M.Close(owner) end
        return
    end
    if input:GetKeyPress(KEY_TAB) then
        s.keyboardFocus=true
        local order={s.buttons.close,s.buttons.favorite,s.search};for _,b in ipairs(s.filters) do order[#order+1]=b end
        for _,row in ipairs(s.rows) do order[#order+1]=row.pick;order[#order+1]=row.favorite end
        for _,id in ipairs({'up','down'}) do order[#order+1]=s.buttons[id] end
        order[#order+1]=s.seek
        for _,id in ipairs({'mode','previous','play','next','queue','mute'}) do order[#order+1]=s.buttons[id] end
        order[#order+1]=s.volume
        if s.modeMenu:IsVisible() then for _,b in ipairs(s.options) do order[#order+1]=b end end
        local visible={};for _,b in ipairs(order) do if b:IsVisible() and not b.props.disabled then visible[#visible+1]=b end end
        local index=0;for i,b in ipairs(visible) do if b==UI.GetFocus() then index=i end end
        Focus(s,visible[(index+(input:GetQualifierDown(QUAL_SHIFT) and -2 or 0))%#visible+1])
    end
    if s.modeMenu:IsVisible() and (input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_DOWN)) then
        for i,b in ipairs(s.options) do if b==UI.GetFocus() then UI.SetFocus(s.options[(i+(input:GetKeyPress(KEY_UP) and 1 or 0))%3+1]);break end end
    end
end
return M
