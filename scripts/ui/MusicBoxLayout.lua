-- music-box.css uses CSS viewport pixels, outside the scaled home ui-surface.
local M={}
function M.Measure(cw,ch,logicalW)
    local medium=cw<=1000;local short=ch<=650;local compact=ch<=450
    local w=math.min(medium and 720 or 880,cw-64)
    local h=compact and ch-40 or short and ch-64 or math.min(620,ch-112)
    local header=compact and 48 or short and 56 or 70;local transport=compact and 88 or short and 96 or 108
    local deck=medium and 244 or 288;local bodyY=header+3;local bodyH=h-4-header-transport
    local dx=medium and 17 or 23;local deckWidth=deck-1-(medium and 32 or 44)
    local lx=deck+19;local lw=w-lx-19;local ly=bodyY+(compact and 8 or 18)
    local filterY=ly+32.5+(compact and 6 or 14);local filterH=compact and 28.5 or 34.5
    local headY=filterY+filterH;local headH=compact and 24 or 34
    local footerH=compact and 37 or 45;local footY=bodyY+bodyH-footerH
    local ty=bodyY+bodyH;local paddingY=short and 10 or 14;local controlY=ty+1+paddingY+16+(compact and 7 or 11)
    local playH=short and 42 or 48;local playW=66;local controlsW=4*38+playW+4*6;local controlsX=(w-controlsW)/2
    local r={header={1,3,w-2,header},deck={1,bodyY,deck,bodyH},library={deck+1,bodyY,w-deck-2,bodyH},
        close={w-61,3+(header-39)/2,38,38},search={w-175,ly,156,32.5},
        filters={lx,filterY,lw,filterH},listHead={lx,headY,lw,headH},list={lx,headY+headH,lw,math.max(0,footY-headY-headH)},
        libraryFooter={lx,footY,lw,footerH},transport={1,ty,w-2,transport},
        seek={67,ty+1+paddingY+2,w-134,12},
        mode={controlsX,controlY+(playH-38)/2,38,38},previous={controlsX+44,controlY+(playH-38)/2,38,38},
        play={controlsX+88,controlY,playW,playH},next={controlsX+160,controlY+(playH-38)/2,38,38},queue={controlsX+204,controlY+(playH-38)/2,38,38},
        modeMenu={controlsX,controlY+playH-58-140,160,140}}
    local vol=medium and 56 or 76
    r.mute={w-23-30-8-vol-8-38,controlY+(playH-38)/2,38,38};r.volume={w-23-30-8-vol,controlY+(playH-12)/2,vol,12}
    local navX=lx+(lw+64-36-70)/2
    r.up={navX,footY+1+(footerH-1-28)/2,32,28};r.down={navX+38,r.up[2],32,28}
    local art=short and 140 or medium and 170 or 204
    local deckTop=bodyY+(short and 10 or medium and 14 or 18)
    if compact then
        deckTop=bodyY+(bodyH-137)/2
        r.art={dx,deckTop+23,80,80};r.heading={dx+88,deckTop+23,deckWidth-88,80};r.spectrum={dx,deckTop+117,deckWidth,20}
    else
        r.art={1+(deck-1-art)/2,deckTop+15+(short and 10 or 14),art,art}
        local hy=r.art[2]+art+(short and 10 or 14);local hh=18+(short and 22 or 26)*1.3+16+3
        r.heading={dx,hy,deckWidth,hh};r.favorite={dx+deckWidth-38,hy+(hh-38)/2,38,38}
        r.description={dx,hy+hh+10,deckWidth,15}
        r.spectrum={dx,short and hy+hh+6 or hy+hh+37,deckWidth,short and 20 or 30}
    end
    r.deckTop={dx,deckTop,deckWidth,15}
    return {w=w,h=h,x=(cw-w)/2,y=(ch-h)/2,k=logicalW/cw,rects=r,medium=medium,short=short,compact=compact,
        sceneColumn=medium and 48 or 60,timeColumn=medium and 38 or 46,numberColumn=medium and 24 or 26,row=57}
end
function M.Apply(s)
    local UI=require 'urhox-libs/UI';local logicalW,logicalH=UI.GetViewportSize()
    local cw=graphics:GetWidth()/graphics:GetDPR();local ch=graphics:GetHeight()/graphics:GetDPR()
    s.layout=M.Measure(cw,ch,logicalW);local l=s.layout;local k=l.k
    s.root:SetStyle({position='absolute',left=0,top=0,width=logicalW,height=logicalH})
    s.frame:SetStyle({position='absolute',left=l.x*k,top=l.y*k,width=l.w*k,height=l.h*k})
    local function Place(widget,r) widget:SetStyle({position='absolute',left=r[1]*k,top=r[2]*k,width=r[3]*k,height=r[4]*k}) end
    for name,widget in pairs(s.buttons) do local r=l.rects[name];widget:SetVisible(r~=nil);if r then Place(widget,r) end end
    Place(s.search,l.rects.search);Place(s.list,l.rects.list);Place(s.seek,l.rects.seek);Place(s.volume,l.rects.volume)
    Place(s.modeMenu,l.rects.modeMenu)
    local f=l.rects.filters;local bw=(f[3]-20)/6
    for i,b in ipairs(s.filters) do Place(b,{f[1]+(i-1)*(bw+4),f[2],bw,f[4]}) end
    for _,row in ipairs(s.rows or {}) do row:SetStyle({height=57*k,paddingLeft=2*k,paddingBottom=k});row.favorite:SetStyle({width=30*k,height=40*k});row.pick:SetStyle({height=56*k}) end
    for i,b in ipairs(s.options or {}) do b:SetStyle({left=7*k,top=(7+(i-1)*42)*k,width=146*k,height=42*k}) end
    s.listBody:SetHeight(#s.tracks*57*k)
    s.cssWidth=cw;s.cssHeight=ch
end
return M
