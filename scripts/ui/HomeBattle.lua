-- Source home.js selectable map cards. Desktop overflow scrolls above the CTA.
local UI=require 'urhox-libs/UI'
local Panel=require 'urhox-libs/UI/Widgets/Panel'
local D=require 'ui.SourceDraw'
local Paragraph=require 'ui.SourceParagraph'
local Button=require 'ui.SourceButton'
local Page=Panel:Extend('VoxMapPage')
local modes={{'target','对战 AI','和 AI 战车交火（靶车会还击、会开车之后开放）'},{'tower','能量站争夺','两队抢三个能量站（标准对战地图）'},{'sliders','自定义房间','自己定规则，档位不限，大型机器人也能上场'}}
function Page:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout()
    D.Text(vg,'选择模式',r.x,r.y+26,42)
    D.Text(vg,'选好模式和档位，点下方「开始战斗」或按 Enter',r.x,r.y+78,13,D.muted,'vox-body')
    local cw=(r.w-16)/3
    for i,m in ipairs(modes) do local x=r.x+(i-1)*(cw+8);local y=r.y+590
        nvgSave(vg);nvgGlobalAlpha(vg,.62);D.Panel(vg,x,y,cw,176,14);D.Icon(vg,m[1],x+25,y+25,24,D.muted);D.Text(vg,m[2],x+14,y+71,19)
        self.paragraphs[i]:Draw(vg,m[3],x+14,y+103,cw-28);D.Icon(vg,'lock',x+14,y+148,15,D.muted);D.Text(vg,'开发中',x+34,y+147,14,D.muted);nvgRestore(vg)
    end
end
local Card=Panel:Extend('VoxMapCard')
function Card:Render(vg)
    D.Begin(vg);local r=self:GetAbsoluteLayout();local selected=(self.owner.app.selectedMap or 'trial')==self.mapId
    nvgSave(vg);D.Panel(vg,r.x,r.y,r.w,r.h,14)
    if selected then D.Rect(vg,r.x,r.y,4,r.h,D.orange) end
    local ex,ey=r.x+22,r.y+22;local trial=self.mapId=='trial'
    D.Path(vg,{ex+21,ey,ex+63,ey,ex+84,ey+42,ex+63,ey+84,ex+21,ey+84,ex,ey+42})
    nvgFillColor(vg,D.Color(selected and D.orange or {42,46,53,255}));nvgFill(vg)
    D.Icon(vg,trial and 'flag' or 'target',ex+21,ey+21,42,selected and D.ink or D.muted,2.4)
    local x=r.x+122
    if trial then D.Rect(vg,x,r.y+22,62,21,D.white);D.Text(vg,'快速开始',x+8,r.y+25,14,D.ink)
    else D.Text(vg,'[debug]坠舰陨坑地图测试',x,r.y+22,13,D.orange,'vox-body') end
    D.Text(vg,trial and '试车场' or '坠舰陨坑',x,r.y+52,40)
    self.paragraph:Draw(vg,trial and '自由驾驶、100 米加速道、坡道、靶场和三辆能逐块打坏的靶车。熟悉操控和武器。' or '坠毁战舰、舱内大厅、顶层甲板、陨坑与两座要塞。开自己的车探索，N 键切换区域。',x,r.y+99,r.w-144)
    if trial then
        D.Text(vg,'出战档位',x,r.y+166,16,D.muted)
        local fit=self.fitTier;D.Icon(vg,fit and 'check' or 'warn',x,r.y+203,16,fit and D.green or D.orange)
        D.Text(vg,fit and ('这辆车最低能进 '..fit.name) or '这辆车超出了所有档位的上限',x+22,r.y+202,13,D.muted,'vox-body')
    end
    nvgRestore(vg)
end
local M={}
function M.Create(s)
    local w=require('controls.TouchMode').Enabled() and 500 or math.min(560,s.width*.4)-56
    local content=Page{width=w,height=784,position='relative'}
    content.paragraphs={};for i=1,3 do content.paragraphs[i]=Paragraph.New(12,19.2) end
    s.modeCards={}
    for i,id in ipairs({'trial','crater'}) do
        local card=s.Track(Card{position='absolute',left=0,top=i==1 and 113 or 360,width=w,height=i==1 and 239 or 218,onClick=function() s.app.selectedMap=id;s.revision=-1 end})
        card.owner=s;card.mapId=id;card.paragraph=Paragraph.New(13,20.8);card.fitTier=s.app.blueprint:Stats().fitTier;content:AddChild(card);s.modeCards[id]=card
    end
    for i=1,5 do
        content:AddChild(s.Track(Button{text='T'..i,sourceKind='tier',selected=i==s.app.tier,position='absolute',left=185+(i-1)*56,top=269.6,width=52,height=34,
            onClick=function() s.app.tier=i;s.app.hangar:SetTier(i);s.revision=-1 end}))
    end
    return UI.ScrollView{position='absolute',left=28,top=60,width=w+12,height=math.max(280,s.height-190),scrollY=true,showScrollbar=true,children={content}}
end
return M
