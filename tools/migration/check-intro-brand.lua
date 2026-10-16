-- Exercise production drawing with stateful NanoVG doubles; not pixel acceptance.
local checks,drawCalls=0,0
local function Check(value,message)assert(value,message);checks=checks+1 end
local calls={};local alpha=1;local stack={};local D=package.loaded['ui.SourceDraw']
local function Record(kind,...)
 calls[#calls+1]={kind=kind,args={...},alpha=alpha};drawCalls=drawCalls+1
end
function D.Width(_,text,size,_,spacing)return utf8.len(text)*(size*.6+(spacing or 0)) end
function D.Rect(_,...)Record('rect',...) end
function D.Line(_,...)Record('line',...) end
function D.Text(_,...)Record('text',...) end
local images=package.loaded['urhox-libs/UI/Core/ImageCache']
function images.Get(path)return path=='logo' and 1 or 2 end
function images.GetSize(_)return 512,512 end
function nvgSave(_)stack[#stack+1]=alpha end
function nvgRestore(_)Check(#stack>0,'restore without save');alpha=table.remove(stack) end
function nvgGlobalAlpha(_,value)alpha=value end
function nvgIntersectScissor(_,...)Record('clip',...) end
function nvgBeginPath(_)end
function nvgCircle(_,...)Record('circle',...) end
function nvgRect(_,...)Record('image-rect',...) end
function nvgImagePattern(_,...)Record('pattern',...);return {} end
function nvgFillPaint(...)end
function nvgFill(...)end
NVG_ALIGN_RIGHT=4
local Brand=require 'ui.IntroBrand'
local owner={downloaded=true,data={images={['company-emblem']='logo',['division-insignia']='badge'}}}
for _,viewport in ipairs({{1920,1080},{2400,1080},{1920,1200}}) do
 for _,age in ipairs({0,.35,.5,.65,.9,1.25,1.75,2.9}) do
  calls={};local w,h=viewport[1],viewport[2];Brand.Draw(1,owner,w,h,h/100,age)
  Check(#stack==0 and alpha==1,'draw must restore global state')
  Check(calls[1].kind=='rect' and calls[1].args[5][1]==12 and calls[1].args[5][2]==13 and calls[1].args[5][3]==16,'source graphite background')
  local textCount,circle,clippedLetters=0,nil,0
  local byText={}
  for _,call in ipairs(calls) do
   if call.kind=='text' then textCount=textCount+1;byText[call.args[1]]=call
   elseif call.kind=='circle' then circle=call
   elseif call.kind=='clip' and call.args[4]==10*h/100 then clippedLetters=clippedLetters+1 end
  end
  Check(textCount==9,'four glyphs + English + four metadata labels')
  Check(circle and math.abs(circle.args[3]-20*h/100*Brand.Plan(age).mask)<1e-9,'source circular image reveal')
  Check(clippedLetters==4,'each Chinese glyph owns a clipping window')
  local en=byText['INTERSTELLAR PROSPECTS LTD.']
  Check(en.args[6]=='vox-code','source mono face')
  Check(math.abs(en.alpha-Brand.Plan(age).wordAlpha*Brand.Plan(age).englishAlpha)<1e-12,'nested opacity compositing')
  Check(byText['EST. 2187']~=nil,'source lower right identifier')
  Check(byText['PUBLIC SERVICE FILM — NO.077'].args[2]==w*.04,'source 4vw gutter')
  if age==0 then Check(en.alpha==0 and circle.args[3]==0,'early layer should remain hidden') end
  if age>=1.75 then Check(en.alpha==1 and circle.args[3]==15*h/100,'settled layer is complete') end
 end
end
local promo=assert(io.open('scripts/ui/IntroPromo.lua','r')):read('*a')
Check(promo:find("require('ui.IntroBrand').Draw(vg,I,w,h,u,t)",1,true)~=nil,'production logo route')
local caption=promo:match("if I.caption and I.caption~='' then(.-)\n end")
Check(caption and caption:find('page.caption.font=\'vox-title\'',1,true) and caption:find('page.caption.lineHeight=4.8*u',1,true),'retain subtitle interface')
return {checks=checks,drawCalls=drawCalls}
