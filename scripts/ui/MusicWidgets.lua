local D=require 'ui.SourceDraw';local MD=require 'ui.MusicDraw'
local Button=require('urhox-libs/UI/Widgets/Button'):Extend('VoxMusicButton')
function Button:Render(vg)
    local w,h,s=MD.Local(vg,self);local p=self.props;local hover=self.state.hovered
    if p.disabled then nvgGlobalAlpha(vg,(s.alpha or 1)*.3) end
    local color=p.pressed and {255,188,101,255} or {182,200,208,255}
    if p.kind=='filter' then
        local backgroundH=h-2;local points={0,0,w,0,w,backgroundH-14,w-14,backgroundH,0,backgroundH}
        if p.pressed then require('ui.SourceRelief').Draw(vg,0,0,w,backgroundH,false,true,points,true);D.Rect(vg,0,backgroundH-2,w-12,2,D.orange)
        else D.Path(vg,points);nvgFillColor(vg,D.Color(hover and {64,83,94,255} or {47,58,64,255}));nvgFill(vg) end
        D.Rect(vg,0,0,w,1.5,{142,198,249,128});D.Rect(vg,0,backgroundH-1.5,w-12.5,1.5,{11,36,75,128})
        MD.Text(vg,p.text,w/2,(h-16.5)/2,11,p.pressed and {219,238,255,255} or {174,191,199,255},nil,NVG_ALIGN_CENTER,16.5)
    elseif p.kind=='track' then
        local t=p.track;local l=s.layout;local selected=s.player:Track() and s.player:Track().id==t.id
        local accent=MD.Color(s.player.catalog.groups[t.group].color)
        MD.Text(vg,t.number,10,(h-16)/2,16,selected and accent or {138,161,173,255},'vox-display',nil,16)
        local nx=10+l.numberColumn+6;local tx=w-4-l.timeColumn;local gx=tx-6-l.sceneColumn
        MD.Text(vg,t.title,nx,(h-34.5)/2,12,selected and accent or nil)
        nvgSave(vg);nvgIntersectScissor(vg,nx,0,math.max(0,gx-6-nx),h)
        MD.Text(vg,t.english,nx,(h-34.5)/2+21,9,{148,169,180,255},'vox-music-latin',nil,13.5);nvgRestore(vg)
        MD.Text(vg,s.player.catalog.groups[t.group].title,gx,(h-15)/2,10,{175,192,200,255})
        MD.Text(vg,MD.Time(t.duration),tx,(h-15)/2,15,{185,203,212,255},'vox-display',nil,15)
    elseif p.kind=='option' then
        if hover then D.Rect(vg,0,0,w,h,{88,119,135,80}) end
        MD.Icon(vg,p.icon,12,(h-20)/2,20,color);MD.Text(vg,p.text,44,(h-18)/2,12,color)
    else
        local icon=p.icon;local size=p.kind=='favorite' and 16 or p.kind=='play' and 24 or p.kind=='scroll' and 15 or 20
        if p.kind~='favorite' then
            local points=p.kind=='play' and {8,0,w,0,w-8,h,0,h} or {0,0,w,0,w,h-14,w-14,h,0,h}
            if p.kind=='play' then
                D.Path(vg,points);nvgFillColor(vg,D.Color(hover and {172,233,255,255} or D.orange));nvgFill(vg)
                color={18,38,48,255}
            else
                D.Path(vg,points);nvgFillColor(vg,D.Color(hover and {84,106,117,255} or {21,28,33,128}));nvgFill(vg)
            end
            if p.kind=='play' then
                D.Rect(vg,8,0,w-8,1,{191,236,255,255});D.Rect(vg,0,h-1,w-8,1,{191,236,255,255})
            else MD.CutEdges(vg,0,0,w,h,{120,144,156,69},14);D.Rect(vg,0,0,w,1.5,{142,198,249,128});D.Rect(vg,0,h-1.5,w-12.5,1.5,{11,36,75,128}) end
        end
        if hover and p.kind~='play' then color={255,255,255,255} end
        if p.pressed then color={255,188,101,255} end
        local ix,iy=(w-size)/2,(h-size)/2
        if p.rotate then nvgSave(vg);nvgTranslate(vg,w/2,h/2);nvgRotate(vg,p.rotate);MD.Icon(vg,icon,-size/2,-size/2,size,color);nvgRestore(vg)
        else MD.Icon(vg,icon,ix,iy,size,color,p.pressed and icon=='heart' and {255,188,101,34} or nil) end
    end
    MD.Focus(vg,w,h,self);nvgRestore(vg)
end
local Row=require('urhox-libs/UI/Widgets/Panel'):Extend('VoxMusicRow')
function Row:Render(vg)
    local w,h,s=MD.Local(vg,self);local t=self.track;local current=s.player:Track();local active=current and current.id==t.id
    if active then D.Rect(vg,0,0,w,h,{63,86,98,107});D.Rect(vg,0,0,2,h,MD.Color(s.player.catalog.groups[t.group].color))
    elseif self.pick.state.hovered then D.Rect(vg,0,0,w,h,{58,76,85,80}) end
    D.Rect(vg,0,h-1,w,1,{129,154,162,28});nvgRestore(vg)
end
local Field=require('urhox-libs/UI/Widgets/TextField'):Extend('VoxMusicSearch')
function Field:Render(vg)
    local w,h,s=MD.Local(vg,self);D.Rect(vg,0,0,w,h,{20,27,32,255});MD.Stroke(vg,0,0,w,h,{114,137,150,101})
    MD.Icon(vg,'search',10,(h-15)/2,15,{152,178,192,255});local value=self.props.value or ''
    self.textAreaX_=self:GetAbsoluteLayout().x+33*s.layout.k;self.charPositions_={0};local count=0
    for _,cp in utf8.codes(value) do count=count+1;local prefix=value:sub(1,(utf8.offset(value,count+1) or #value+1)-1);self.charPositions_[count+1]=D.Width(vg,prefix,11,'vox-body')*s.layout.k end
    nvgSave(vg);nvgIntersectScissor(vg,33,0,w-42,h)
    local cursor=self.charPositions_[self.state.cursorPos+1] or 0;local textWidth=self.charPositions_[#self.charPositions_] or 0
    local visibleWidth=(w-42)*s.layout.k;local scroll=self.state.scrollX or 0
    if cursor-scroll>visibleWidth then scroll=cursor-visibleWidth+2*s.layout.k elseif cursor<scroll then scroll=cursor end
    scroll=math.max(0,math.min(scroll,math.max(0,textWidth-visibleWidth)));self.state.scrollX=scroll;self.scrollX_=scroll
    local offset=scroll/s.layout.k
    local a,b=self:GetSelectionRange()
    if a then D.Rect(vg,33+(self.charPositions_[a+1] or 0)/s.layout.k-offset,7,((self.charPositions_[b+1] or 0)-(self.charPositions_[a+1] or 0))/s.layout.k,h-14,{75,112,150,180}) end
    MD.Text(vg,value~='' and value or '搜索曲目',33-offset,(h-16.5)/2,11,value~='' and nil or {154,174,185,255},nil,nil,16.5)
    if self.state.focused and self.state.cursorBlink then D.Rect(vg,33+(self.charPositions_[self.state.cursorPos+1] or 0)/s.layout.k-offset,7,1,h-14,D.white) end
    nvgRestore(vg);MD.Focus(vg,w,h,self);nvgRestore(vg)
end
local Slider=require('urhox-libs/UI/Widgets/Slider'):Extend('VoxMusicSlider')
function Slider:Render(vg)
    local w,h,s=MD.Local(vg,self);local ratio=(self.props.value-self.props.min)/math.max(.001,self.props.max-self.props.min)
    D.Rect(vg,0,(h-4)/2,w,4,self.props.progress and {145,172,187,80} or {145,172,187,112})
    if self.props.progress then D.Rect(vg,0,(h-4)/2,w*ratio,4,MD.Color(s.player.catalog.groups[(s.player:Track() or s.player.catalog.tracks[1]).group].color)) end
    D.Rect(vg,ratio*(w-10),0,10,12,{219,238,255,255});MD.Stroke(vg,ratio*(w-10),0,10,12,D.orange)
    MD.Focus(vg,w,h,self);nvgRestore(vg)
end
function Slider:UpdateValueFromPosition(x)
    local r=self:GetAbsoluteLayoutForHitTest();local k=self.owner.layout.k
    local ratio=math.max(0,math.min(1,(x-r.x-5*k)/math.max(1,r.w-10*k)))
    self:SetValue(self.props.min+ratio*(self.props.max-self.props.min))
end
function Slider:OnKeyDown(key)
    if self.props.disabled then return end
    if key==KEY_LEFT or key==KEY_RIGHT then
        self:SetValue(self.props.value+(key==KEY_LEFT and -1 or 1)*(self.props.step or 1))
        if self.props.onChangeEnd then self.props.onChangeEnd(self,self.props.value) end
    end
end
return {Button=Button,Row=Row,Field=Field,Slider=Slider}
