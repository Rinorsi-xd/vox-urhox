local checks=0
local function Check(value,message)assert(value,message);checks=checks+1 end
local D=package.loaded['ui.SourceDraw'];local calls={};local stack={};local alpha=1
local function Record(kind,...)calls[#calls+1]={kind=kind,args={...},alpha=alpha}end
function D.Rect(_,...)Record('rect',...)end
function D.Line(_,...)Record('line',...)end
function D.Text(_,...)Record('text',...)end
function nvgSave(_)stack[#stack+1]=alpha end
function nvgRestore(_)Check(#stack>0,'save/restore ownership');alpha=table.remove(stack)end
function nvgGlobalAlpha(_,value)alpha=value end
function nvgBeginPath(_)Record('begin')end
function nvgRect(_,...)Record('path-rect',...)end
function nvgRoundedRect(_,...)Record('round',...)end
function nvgFillColor(_,...)end
function nvgFill(_)Record('fill')end
function nvgTranslate(_,...)end
function nvgScale(_,...)end
function nvgRGBA(...)return {...}end
function nvgRadialGradient(_,...)Record('radial',...);return {}end
package.loaded['ui.IntroPage']={Image=function(_,...)Record('image',...)end}
local Film=require 'ui.IntroFilm'
for _,viewport in ipairs({{1920,1080,1},{2400,1080,.35},{1920,1200,.8}})do
 local w,h,k=table.unpack(viewport)
 local owner={shot='idyll',time=4,age=1,log={{shot='logo',t=.1},{shot='idyll',t=3}}}
 calls={};Film.Under(1,owner,w,h,h/100,k)
 Check(#stack==0 and alpha==1,'film draw restores state')
 local begins,fills,lines,legal=0,0,0,0
 for _,call in ipairs(calls)do
  if call.kind=='begin'then begins=begins+1 elseif call.kind=='fill'then fills=fills+1
  elseif call.kind=='path-rect'then lines=lines+1 elseif call.kind=='text'and call.args[1]:find('实机',1,true)then legal=legal+1 end
 end
 Check(lines==math.floor(h*k/3)+2,'one path includes every 1px/3px scanline and vignette rectangle')
 Check(begins==3 and fills==3,'scanline fill is batched, not hundreds of fills')
 Check(legal==1,'source disclaimer remains visible on live scene')
 calls={};Film.Over(1,owner,w,h,h/100)
 Check(#calls==2 and calls[1].kind=='rect'and calls[2].kind=='rect','settled film draws only two bars on top')
 Check(calls[1].args[4]==h*.085,'source 8.5vh black bar')
 owner.time=9;owner.shot='order';owner.log[#owner.log+1]={shot='prosper',t=7}
 calls={};Film.Over(1,owner,w,h,h/100);Check(#calls==0,'comic has no cinema bars after transition')
end
return {checks=checks}
