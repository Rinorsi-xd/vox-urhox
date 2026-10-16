-- Source .slam.white wins the later .slam rule by selector specificity.
local G=require 'ui.IntroGlyphs'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local M={}
local function Cubic(t,a,b)local q=1-t;return 3*q*q*t*a+3*q*t*t*b+t*t*t end
local function Ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local lo,hi=0,1
 for _=1,22 do local p=(lo+hi)/2;if Cubic(p,x1,x2)<t then lo=p else hi=p end end
 return Cubic((lo+hi)/2,y1,y2)
end
function M.Plan(age)
 if age<0 or age>=1.44 then return {visible=false} end
 local t=Ease(age/.24,.2,.8,.3,1.2);local first=t<.7;local q=first and t/.7 or (t-.7)/.3
 return {visible=true,scale=first and 2.8+(.94-2.8)*q or .94+.06*q,
  rotation=first and -10+6*q or -4,alpha=age>=1.2 and 1-Ease((age-1.2)/.24,.42,0,1,1) or first and q or 1}
end
local function Text(vg,text,x,y,size,spacing,fill,stroke,width)
 local baseline=y+(size-size*(G.Ascent()+G.Descent()))/2+size*G.Ascent()
 for _,cp in utf8.codes(text)do local c=utf8.char(cp);G.Draw(vg,c,x,baseline,size,fill,stroke,width or 0);x=x+G.Glyph(c).advance*size+spacing end
end
function M.Draw(vg,w,h,u,age,mine)
 local p=M.Plan(age);if not p.visible then return end
 local text='击毁！';local sub=mine and '绩效 +1' or '（感谢友军炮火）';local size=11*u;local small=size*.28
 local width=G.Width(text,size,.02*size);local subWidth=G.Width(sub,small,.1*small);local height=size+small*1.4
 nvgSave(vg);nvgTranslate(vg,w/2,h/2);nvgRotate(vg,p.rotation*math.pi/180);nvgScale(vg,p.scale,p.scale);nvgTranslate(vg,-width/2,-height/2);nvgGlobalAlpha(vg,p.alpha)
 Text(vg,text,u,u,size,.02*size,{122,216,255,255},{122,216,255,255},.5*u)
 Text(vg,text,0,0,size,.02*size,{255,255,255,255},{17,17,17,255},.5*u)
 Text(vg,sub,(width-subWidth)/2,size+small*.4,small,.1*small,{255,255,255,255},nil,0)
 nvgRestore(vg)
end
return M
