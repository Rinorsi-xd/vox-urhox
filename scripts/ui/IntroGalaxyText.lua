-- Frozen GalaxyMap DOM text; the map canvas remains owned by IntroPromo.
local D=require 'ui.SourceDraw'
local nvgGlobalAlpha=require('ui.IntroOpacity').Set
local M={}
local names={'锈带 · ','灰烬环 · ','暮光峡 · ','霜原 · ','坠星滩 · ','铁砧座 · ','回声裂谷 · ','第 7 边境 · '}
function M.Plan(w,h,u,count)
 local y=h*.14;local size=1.3*u
 return {x=w*.04,y=y,small=size,titleY=y+size+1.4*u,title=3*u,
  numberY=y+size+1.4*u+3*u,number=16*u,totalY=y+size+1.4*u+19*u,total=3*u,
  count=string.format('%03d',count),tickBottom=h*.78,tick=1.6*u,tag=2*u,right=w*.96}
end
function M.Draw(page,vg,I,w,h,u,count,last)
 local p=M.Plan(w,h,u,count);local grey={138,147,163,255};local red={255,59,48,255}
 D.Text(vg,'星际前途 · 资产安全监控',p.x,p.y,p.small,grey,'vox-display',nil,p.small*.3,false,p.small)
 D.Text(vg,'受袭开采星区',p.x,p.titleY,p.title,{255,255,255,255},'vox-title',nil,p.title*.1,false,p.title)
 D.Text(vg,p.count,p.x,p.numberY,p.number,red,'vox-display',nil,p.number*.02,false,p.number)
 D.Text(vg,'/ 200',p.x,p.totalY,p.total,grey,'vox-display',nil,0,false,p.total)
 local tag='WARNING · 多星区同时遭到攻击';local tw=D.Width(vg,tag,p.tag,'vox-title',p.tag*.14)+p.tag*2.4
 local th=p.tag*2.2;local tx=p.right-tw
 nvgSave(vg);local cycle=I.age%.8
 nvgGlobalAlpha(vg,(cycle<.2 or cycle>=.6) and 1 or .675)
 D.Rect(vg,tx,p.y,tw,th,{216,23,12,255})
 D.Text(vg,tag,tx+p.tag*1.2,p.y+p.tag*.6,p.tag,{255,255,255,255},'vox-title',nil,p.tag*.14,false,p.tag)
 nvgRestore(vg)
 local state=page.galaxyText
 if not state or I.age<state.time then state={rows={},count=0};page.galaxyText=state end
 if count~=state.count then
  state.count=count
  if last and count%3==0 then
   state.rows[#state.rows+1]={text='▲ '..names[last.id%#names+1]..'开采星区 #'..last.id..' ',at=I.age}
   if #state.rows>7 then table.remove(state.rows,1) end
  end
 end
 state.time=I.age
 for index,row in ipairs(state.rows) do
  local t=math.min(1,(I.age-row.at)/.16);local y=p.tickBottom-(#state.rows-index+1)*p.tick*2
  nvgSave(vg);nvgGlobalAlpha(vg,t);local x=p.x-w*.02*(1-t)
  D.Text(vg,row.text,x,y,p.tick,{200,204,212,255},'vox-title',nil,0,false,p.tick*2)
  D.Text(vg,'失守',x+D.Width(vg,row.text,p.tick,'vox-title'),y,p.tick,red,'vox-title',nil,0,false,p.tick*2)
  nvgRestore(vg)
 end
end
return M
