-- Preserve the source em/fz hierarchy without changing the imported words.
local Paragraph=require 'ui.SourceParagraph'
local M={}
function M.Field(text,u)
 local at=text:find('*',1,true)
 if not at then return text end
 return {{text=text:sub(1,at-1),font='vox-title',size=1.65*u,color={238,248,255,255}},
  {text=text:sub(at),font='vox-title',size=1.25*u,color={214,240,255,140}}}
end
function M.Terms(data)
 local rows={};local fine=false
 for line in (data.terms..'\n'):gmatch('(.-)\n')do
  line=line:gsub('[ \t\r\n]+',' '):match('^[ \t\r\n]*(.-)[ \t\r\n]*$')
  if line~='' then
   local start=line:find('（附则一）',1,true)==1
   fine=fine or start
   rows[#rows+1]={text=line,fine=fine,separator=start,paragraph=Paragraph.New(1,1)}
   rows[#rows].paragraph.font='vox-title'
  end
 end
 rows[#rows+1]={text=data.contractEgg,egg=true,paragraph=Paragraph.New(1,1)}
 rows[#rows].paragraph.font='vox-title'
 return rows
end
function M.Style(row,u)
 return {size=(row.fine and 1.12 or 1.4)*u,lineHeight=(row.fine and 1.904 or 2.59)*u,
  color=row.egg and {255,77,66,255} or row.fine and {214,240,255,140} or {195,219,232,255},
  before=row.separator and 1.4*u or 0}
end
return M
