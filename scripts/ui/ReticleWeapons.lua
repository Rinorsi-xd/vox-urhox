local D=require 'ui.SourceDraw'
local R=require 'ui.ReticleDraw'
local State=require 'ui.ReticleState'
local M={}
function M.Render(vg,v,l)
    local ImageCache=require 'urhox-libs/UI/Core/ImageCache'
    local k=l.k;local s=v.session
    local key=l.width..'/'..l.height..'/'..s.weapons.current..'/'..#s.weapons.groups
    if v.chipLayoutKey~=key then v.chipLayoutKey=key;v.chipLayout=State.Chips(l,s.weapons.groups,s.weapons.current,s.story~=nil) end
    local boxes=v.chipLayout
    for i,g in ipairs(s.weapons.groups) do
        local b=boxes[i];local x,y,w,h=b.x,b.y,b.w,b.h;local c=10*k;local selected=b.selected
        local state=v.chipStates and v.chipStates[g.kind] or {};local clock=v.clock or 0
        local hurt=(state.hurt or 0)>clock;local fix=(state.fix or 0)>clock
        local edge=fix and {63,230,255,255} or hurt and R.warn or selected and R.white or {255,255,255,77}
        nvgSave(vg);nvgGlobalAlpha(vg,(selected or hurt or fix) and 1 or .6)
        local points=b.special and {x+h*.7,y,x+w-h*.7,y,x+w,y+h,x,y+h} or {x+c,y,x+w-c,y,x+w,y+c,x+w,y+h-c,x+w-c,y+h,x+c,y+h,x,y+h-c,x,y+c}
        R.Poly(vg,points,selected and {10,15,20,82} or {10,15,20,64},edge,(selected and 2 or 1.3)*k)
        local weapon=g.weapons[1];local path=weapon and 'UI/WeaponIcons/'..weapon.type..'.png'
        local img=path and ImageCache.Get(path)
        if img and img>0 then
            local ix=x+(selected and 94 or b.special and 30 or 16)*k
            local iy=y+5*k;local iw=w-(selected and 108 or b.special and 60 or 32)*k;local ih=h-(selected and 22 or 10)*k
            local imageW,imageH=nvgImageSize(vg,img);local scale=math.min(iw/imageW,ih/imageH)
            local pw,ph=imageW*scale,imageH*scale
            nvgBeginPath(vg);nvgRect(vg,ix+(iw-pw)/2,iy+(ih-ph)/2,pw,ph)
            nvgFillPaint(vg,nvgImagePattern(vg,ix+(iw-pw)/2,iy+(ih-ph)/2,pw,ph,0,img,.86));nvgFill(vg)
        end
        if selected then
            local output=tostring(math.floor(g.output*100+.5))
            R.Text(vg,output,x+16*k,y+h*.72,34*k,R.white,nil,s.story~=nil)
            R.Text(vg,'%',x+16*k+D.Width(vg,output,34*k,s.story and 'vox-display' or 'vox-hud'),y+h*.72,13*k,R.muted,nil,s.story~=nil)
            R.Text(vg,g.name..(#g.weapons>1 and ' ×'..#g.weapons or ''),x+w-12*k,y+h-5*k,11*k,R.muted,NVG_ALIGN_RIGHT,s.story~=nil)
        end
        local ready=State.Clamp(s.weapons:Readiness(g))
        if selected then
            local x1=x+c+(w-2*c)*ready
            R.Poly(vg,{x+c,y+h+4*k,x+w-c,y+h+4*k,x+w-c-5*k,y+h+9*k,x+c+5*k,y+h+9*k},{255,255,255,38})
            if ready>.004 then R.Poly(vg,{x+c,y+h+4*k,x1,y+h+4*k,math.max(x+c+5*k,x1-5*k),y+h+9*k,x+c+5*k,y+h+9*k},{232,237,240,255}) end
        elseif ready<.995 then D.Line(vg,x+c,y+h+3*k,x+c+(w-2*c)*ready,y+h+3*k,R.white,2*k) end
        local kx,ky=x+w+8*k,y+h/2-11*k
        R.Poly(vg,{kx,ky,kx+22*k,ky,kx+22*k,ky+22*k,kx,ky+22*k},nil,selected and {255,106,19,255} or {255,255,255,89},(selected and 1.8 or 1.2)*k)
        R.Text(vg,tostring(i),kx+11*k,ky+17*k,16*k,selected and {255,106,19,255} or R.white,NVG_ALIGN_CENTER,s.story~=nil)
        nvgRestore(vg)
    end
end
return M
