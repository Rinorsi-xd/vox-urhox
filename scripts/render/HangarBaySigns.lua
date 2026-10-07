-- shared/scene/hangarTextures.js: same seeded paint wear and design coordinates.
local C=require 'render.HangarCanvas'
local Number=require 'render.HangarNumber'
local M={}
local function Wear(vg,w,h,seed,count)
    local state=seed
    local function Rand() state=(state*1664525+1013904223)&0xffffffff;return state/4294967296 end
    nvgSave(vg);nvgGlobalCompositeOperation(vg,NVG_DESTINATION_OUT)
    for _=1,count do
        local alpha=.15+Rand()*.5;local x,y=Rand()*w,Rand()*h
        local a,b=Rand(),Rand();local s=2+a*(b<.1 and 40 or 10)
        C.Rect(vg,x,y,s,s*(.3+Rand()),{0,0,0,math.floor(alpha*255+.5)})
    end
    nvgRestore(vg)
end
function M.Bay(vg,info)
    local paint={232,236,240,235}
    Number.Draw(vg,info.no,1024,850,900,paint)
    C.Text(vg,'整备位',250,200,130,paint);C.Text(vg,'VOX 轨道改装机库',1798,985,100,paint,false,NVG_ALIGN_RIGHT)
    for _,x in ipairs({150,1898}) do
        C.Path(vg,{x-90,520,x,380,x+90,520});C.Fill(vg,paint)
        C.Rect(vg,x-40,520,80,240,paint)
    end
    Wear(vg,2048,1024,91,2600)
end
function M.Mark(vg,info)
    local paint,dim={223,227,232,255},{141,147,156,255}
    C.Rect(vg,0,0,2048,1126,{37,40,45,255});C.Path(vg,{1878,0,2048,0,2048,170});C.Fill(vg,{21,23,26,255})
    Number.Draw(vg,info.no,540,1056,1080,paint)
    C.Path(vg,{1096,120,1128,120,1064,1006,1032,1006});C.Fill(vg,{232,97,26,255})
    C.Text(vg,'整备位',1170,400,230,paint);C.Text(vg,info.tier.name,1180,540,96,dim)
    C.Rect(vg,1180,590,700,8,dim);C.Text(vg,'VOX 轨道改装机库',1180,700,76,dim)
    C.Rect(vg,1140,876,908,150,{201,206,213,255})
    C.Text(vg,C.Fit(vg,info.name,798,76),1190,978,76,{23,25,29,255})
    Wear(vg,2048,1126,17,1800)
end
return M
