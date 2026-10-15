local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw';local MD=require 'ui.MusicDraw'
local Frame=Panel:Extend('VoxMusicFrame')
function Frame:Render(vg)
    local w,h,s=MD.Local(vg,self);local l=s.layout;local r=l.rects;local p=s.player
    local track=p:Track() or p.catalog.tracks[1];local group=p.catalog.groups[track.group];local accent=MD.Color(group.color)
    D.Path(vg,{0,0,w-14,0,w,14,w,h,0,h});nvgFillColor(vg,nvgRGBA(34,40,44,255));nvgFill(vg)
    MD.CutEdges(vg,0,0,w,h,{139,164,174,255},14,true);D.Rect(vg,0,0,w-14,3,D.orange)
    MD.Stroke(vg,5,5,w-10,h-10,{19,25,28,255})
    local header=r.header;MD.Texture(vg,'header',header[1],header[2],header[3],header[4],{1,3,w-11,3,w-1,13,w-1,header[2]+header[4],1,header[2]+header[4]});D.Rect(vg,1,header[2]+header[4]-1,w-2,1,{113,133,144,255})
    MD.Icon(vg,'music',23,3+(header[4]-31)/2,30,D.orange)
    local brandY=3+(header[4]-45.1)/2
    MD.Text(vg,'STAR FRONTIER / AUDIO ARCHIVE',65,brandY,9,{178,197,206,255},'vox-music-latin',nil,12.6)
    MD.Text(vg,'音乐盒',65,brandY+12.6,26,nil,'vox-title',nil,32.5)
    MD.Text(vg,'VOL. 01',w-190,3+(header[4]-10)/2,10,{178,197,206,255},'vox-music-latin',nil,10)
    D.Rect(vg,w-140,3+(header[4]-10)/2,1,10,{130,150,160,255})
    MD.Text(vg,'13 TRACKS',w-128,3+(header[4]-10)/2,10,{178,197,206,255},'vox-music-latin',nil,10)
    local deck=r.deck;D.Rect(vg,deck[1],deck[2],deck[3]-1,deck[4],{28,34,38,255});D.Rect(vg,deck[1]+deck[3]-1,deck[2],1,deck[4],{96,117,127,101})
    local top=r.deckTop;MD.Text(vg,'舰载声音档案',top[1],top[2],10,{145,166,176,255})
    local status=p:Status();local statusWidth=D.Width(vg,status,10,'vox-body')
    D.Rect(vg,top[1]+top[3]-statusWidth-12,top[2]+5,5,5,accent);MD.Text(vg,status,top[1]+top[3],top[2],10,accent,nil,NVG_ALIGN_RIGHT)
    local art=r.art;local ax,ay,aw,ah=table.unpack(art)
    MD.Image(vg,'archive-cartridge',ax,ay,aw,ah,{ax,ay,ax+aw,ay,ax+aw,ay+ah,ax+14,ay+ah,ax,ay+ah-14})
    D.Rect(vg,ax,ay,aw,1,{101,120,129,255});D.Rect(vg,ax+aw-1,ay,1,ah,{101,120,129,255})
    D.Rect(vg,ax,ay,1,ah-14,{101,120,129,255});D.Rect(vg,ax+14,ay+ah-1,aw-14,1,{101,120,129,255})
    MD.Text(vg,track.number,art[1]+art[3]-10,art[2]+8,28,{255,243,223,255},'vox-display',NVG_ALIGN_RIGHT,28)
    if not l.compact then
        MD.Text(vg,'SF / AUDIO',art[1]+10,art[2]+10,9,{210,227,235,255},'vox-music-latin',nil,9)
        MD.Text(vg,'ORIGINAL SOUNDTRACK',art[1]+10,art[2]+art[4]-21.2,8,{210,227,235,255},'vox-music-latin',nil,11.2)
        MD.Text(vg,'STEREO',art[1]+art[3]-10,art[2]+art[4]-21.2,8,{210,227,235,255},'vox-music-latin',NVG_ALIGN_RIGHT,11.2)
    end
    local heading=r.heading;local titleSize=l.compact and 20 or l.short and 22 or 26
    local groupSize=l.compact and 8 or 9;local engSize=l.compact and 8 or 10
    local groupHeight=groupSize*1.6
    local natural=groupHeight+3+titleSize*1.3+engSize*1.6
    local hy=heading[2]+(heading[4]-natural)/2
    MD.Text(vg,group.label..' / '..group.title,heading[1],hy,groupSize,accent,'vox-music-latin',nil,groupHeight)
    MD.Text(vg,track.title,heading[1],hy+groupHeight+3,titleSize,nil,'vox-title',nil,titleSize*1.3)
    MD.Text(vg,track.english,heading[1],hy+groupHeight+3+titleSize*1.3,engSize,{162,180,189,255},'vox-music-latin',nil,engSize*1.6)
    if not l.short then local desc=r.description;MD.Text(vg,track.description,desc[1],desc[2],10,{170,188,196,255}) end
    local spectrum=r.spectrum;local signalW=D.Width(vg,'LIVE SIGNAL',8,'vox-body');local binsWidth=spectrum[3]-signalW-10
    -- Public SoundSource has no PCM/FFT tap. Preserve the source's idle signal,
    -- rather than displaying randomly animated bars unrelated to the music.
    local canvasDpr=math.min(graphics:GetDPR(),2)
    for i=0,47 do D.Rect(vg,spectrum[1]+i*binsWidth/48,spectrum[2]+spectrum[4]-2,math.max(1/canvasDpr,binsWidth/48-3),2,{accent[1],accent[2],accent[3],77}) end
    MD.Text(vg,'LIVE SIGNAL',spectrum[1]+spectrum[3],spectrum[2]+spectrum[4]-10,8,{144,167,176,255},'vox-music-latin',NVG_ALIGN_RIGHT,8)
    local filter=r.filters;local headingY=r.search[2]
    MD.Text(vg,'曲目档案',filter[1],headingY+(32.5-(l.compact and 16 or 18)*1.4)/2,l.compact and 16 or 18,nil,'vox-title',nil,(l.compact and 16 or 18)*1.4)
    MD.Text(vg,string.format('%02d',#s.tracks),filter[1]+D.Width(vg,'曲目档案',l.compact and 16 or 18,'vox-title')+6,headingY+(32.5-17)/2,17,{138,171,185,255},'vox-display',nil,17)
    local listHead=r.listHead;local sceneX=listHead[1]+listHead[3]-34-l.timeColumn-l.sceneColumn
    MD.Text(vg,'曲目',listHead[1]+12,listHead[2]+(l.compact and 5 or 12),10,{144,166,177,255})
    MD.Text(vg,'场景',sceneX,listHead[2]+(l.compact and 5 or 12),10,{144,166,177,255})
    MD.Text(vg,'时长',sceneX+l.sceneColumn,listHead[2]+(l.compact and 5 or 12),10,{144,166,177,255})
    if #s.tracks==0 then
        local list=r.list;MD.Icon(vg,s.filter=='favorites' and 'heart' or 'search',list[1]+list[3]/2-10,list[2]+list[4]/2-26,20,{163,185,196,255})
        MD.Text(vg,s.filter=='favorites' and s.query=='' and '还没有收藏的曲目' or '没有找到曲目',list[1]+list[3]/2,list[2]+list[4]/2+6,12,{163,185,196,255},nil,NVG_ALIGN_CENTER)
    end
    local footer=r.libraryFooter;D.Rect(vg,footer[1],footer[2],footer[3],1,{113,133,144,96})
    local _,scroll=s.list:GetScroll();local first=#s.tracks>0 and math.min(#s.tracks,math.floor(scroll/(57*l.k))+1) or 0
    MD.Text(vg,string.format('%02d / %02d',first,#s.tracks),footer[1],footer[2]+(footer[4]-14)/2,14,{158,183,196,255},'vox-display',nil,14)
    MD.Text(vg,'原声档案',footer[1]+footer[3],footer[2]+(footer[4]-13.5)/2,9,{158,183,196,255},nil,NVG_ALIGN_RIGHT)
    local trans=r.transport;MD.Texture(vg,'transport',trans[1],trans[2],trans[3],trans[4]);D.Rect(vg,1,trans[2],w-2,1,{156,180,192,96})
    local seek=r.seek
    MD.Text(vg,MD.Time(s.seek.state.dragging and s.seek.props.value or p:Position()),23,seek[2]-2,16,{215,228,235,255},'vox-tabular',nil,16)
    MD.Text(vg,MD.Time(p:Duration()),w-23,seek[2]-2,16,{215,228,235,255},'vox-tabular',NVG_ALIGN_RIGHT,16)
    local play=r.play
    MD.Icon(vg,'disc',23,play[2]+(play[4]-24)/2,24,D.orange)
    local tx=57;local tw=r.mode[1]-16-tx
    nvgSave(vg);nvgIntersectScissor(vg,tx,play[2],tw,play[4])
    MD.Text(vg,track.title,tx,play[2]+(play[4]-34.5)/2,12,nil)
    MD.Text(vg,group.title,tx,play[2]+(play[4]-34.5)/2+21,9,{169,192,206,255});nvgRestore(vg)
    MD.Text(vg,math.floor(p.volume*100+.5)..'%',w-23,play[2]+(play[4]-14)/2,14,{196,217,229,255},'vox-display',NVG_ALIGN_RIGHT,14)
    nvgRestore(vg)
end
local Menu=Panel:Extend('VoxMusicModeMenu')
function Menu:Render(vg)
    local w,h=MD.Local(vg,self);D.Rect(vg,0,0,w,h,{46,59,67,255});MD.Stroke(vg,0,0,w,h,{146,176,192,255});nvgRestore(vg)
end
local Console=require('urhox-libs/UI/Widgets/Button'):Extend('VoxMusicConsole')
function Console:Render(vg)
    MD.Begin(vg);local r=self:GetAbsoluteLayout();local p=self.player;local small=self.small;local k=small and self.consoleScale or 1
    nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,k,k);local w,h=r.w/k,r.h/k
    require('ui.SourceRelief').Draw(vg,0,0,w,h,false,false,{0,0,w-14,0,w,14,w,h,0,h},true)
    if self.state.hovered then D.Rect(vg,0,0,w,h,{255,255,255,30}) end
    MD.Stroke(vg,0,0,w,h,{142,185,204,128});D.Rect(vg,0,0,3,h,D.orange)
    local art=small and 50 or 74;local ax=small and 11 or 13;local tx=ax+art+(small and 10 or 14)
    MD.Image(vg,'archive-cartridge',ax,(h-art)/2,art,art)
    local labelH=small and 11.2 or 12.6;local titleH=small and 24 or 28.8;local cy=(h-labelH-titleH-15.4-6)/2
    MD.Text(vg,'舰载音频 / AUDIO',tx,cy,small and 8 or 9,{166,184,194,255},'vox-music-latin',nil,labelH)
    MD.Text(vg,'音乐盒',tx,cy+labelH+3,small and 20 or 24,{219,238,255,255},'vox-title',nil,titleH)
    nvgSave(vg);nvgIntersectScissor(vg,tx,0,w-tx-50,h)
    MD.Text(vg,p:Track() and p:Track().title or '原声档案',tx,cy+labelH+titleH+6,11,{189,212,223,255});nvgRestore(vg)
    MD.Icon(vg,'music',w-(small and 32 or 46),(h-(small and 20 or 26))/2,small and 20 or 26,p:CanPlay() and p:Track() and {255,188,101,255} or {136,153,158,255})
    if self.state.focused and self.keyboardFocus then MD.Stroke(vg,4,4,w-8,h-8,{255,188,101,255}) end
    nvgRestore(vg)
end
return {Frame=Frame,Menu=Menu,Console=Console}
