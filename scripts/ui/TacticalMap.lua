local D=require 'ui.SourceDraw'
local M={}
local function Outline(vg,color,width)
    nvgStrokeWidth(vg,width or 2);nvgStrokeColor(vg,D.Color(color));nvgStroke(vg)
end
-- Direct translation of home.js mapSvg; coordinates remain in its 600m viewBox.
function M.Mode(vg,x,y,size,mode)
    nvgSave(vg);nvgTranslate(vg,x+size/2,y+size/2);nvgScale(vg,size/600,size/600)
    D.Rect(vg,-300,-300,600,600,{8,9,12,153})
    D.Rect(vg,-290,-290,580,580,{201,168,116,20});Outline(vg,{255,255,255,32})
    D.Rect(vg,-300,-300,100,600,{255,255,255,12});D.Text(vg,'西高地',-250,0,16,{222,224,230,140},'vox-body',NVG_ALIGN_CENTER)
    D.Rect(vg,195,-300,105,600,{0,0,0,48});D.Text(vg,'东洼地',248,0,16,{222,224,230,140},'vox-body',NVG_ALIGN_CENTER)
    nvgBeginPath(vg);nvgEllipse(vg,5,0,165,62);nvgFillColor(vg,nvgRGBA(0,0,0,69));nvgFill(vg);Outline(vg,{255,255,255,24})
    D.Rect(vg,-128,-26,268,52,{138,143,151,68});Outline(vg,{200,204,211,136})
    D.Text(vg,'舰体大厅',5,32,16,{222,224,230,140},'vox-body',NVG_ALIGN_CENTER)
    D.Path(vg,{-110,-95,-160,-95,-150,-200,-118,-200});nvgFillColor(vg,nvgRGBA(138,143,151,68));nvgFill(vg);Outline(vg,{200,204,211,136})
    D.Text(vg,'舰首',-135,-226,16,{222,224,230,140},'vox-body',NVG_ALIGN_CENTER)
    for _,base in ipairs({{246,'蓝队要塞',{46,168,255,255}},{-246,'红队要塞',{255,74,61,255}}}) do
        local color=base[3]
        nvgBeginPath(vg);nvgEllipse(vg,0,base[1],84,56);nvgFillColor(vg,nvgRGBA(color[1],color[2],color[3],48));nvgFill(vg);Outline(vg,color,3)
        D.Text(vg,base[2],0,base[1]-6,18,D.white,nil,NVG_ALIGN_CENTER)
    end
    local zone={255,106,19,255}
    local function Circle(cx,cy,r)
        nvgBeginPath(vg);nvgCircle(vg,cx,cy,r);nvgFillColor(vg,nvgRGBA(255,106,19,38));nvgFill(vg);Outline(vg,zone,3)
    end
    if mode=='elimination' then Circle(0,0,22);D.Text(vg,'主战场',0,-50,18,zone,nil,NVG_ALIGN_CENTER)
    elseif mode=='conquest' then
        for _,p in ipairs({{-95,165,'A'},{94,-140,'B'},{0,0,'C'}}) do Circle(p[1],p[2],20);D.Text(vg,p[3],p[1],p[2]-14,24,zone,nil,NVG_ALIGN_CENTER) end
    elseif mode=='escort' then
        local route={{0,-234},{0,-205},{45,-150},{110,-160},{224,-100},{224,100},{74,132},{0,178},{0,234}}
        for i=2,#route do D.Line(vg,route[i-1][1],-route[i-1][2],route[i][1],-route[i][2],zone,5) end
    end
    D.Text(vg,'TACTICAL',-271,-271,28,{255,255,255,102})
    nvgRestore(vg)
end
function M.Draw(vg,x,y,size,mode,holo)
    if not holo then return M.Mode(vg,x,y,size,mode) end
    nvgSave(vg);nvgTranslate(vg,x+size/2,y+size/2);nvgScale(vg,size/600,size/600)
    D.Rect(vg,-300,-300,600,600,holo and {6,24,35,130} or {7,10,14,165})
    local c={88,171,194,110}
    for v=-300,300,50 do D.Line(vg,v,-300,v,300,c,1);D.Line(vg,-300,v,300,v,c,1) end
    D.Rect(vg,-128,-26,268,52,{101,179,192,100});D.Text(vg,'舰体大厅',5,36,18,D.orange,nil,NVG_ALIGN_CENTER)
    D.Rect(vg,-160,-200,50,105,{101,179,192,80});D.Text(vg,'舰首',-135,-230,18,D.muted,nil,NVG_ALIGN_CENTER)
    for _,p in ipairs({{0,246,'蓝队要塞',D.orange},{0,-246,'红队要塞',{248,91,100,255}}}) do
        nvgBeginPath(vg);nvgEllipse(vg,p[1],p[2],72,44);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,D.Color(p[4]));nvgStroke(vg)
        D.Text(vg,p[3],p[1],p[2]-10,18,p[4],nil,NVG_ALIGN_CENTER)
    end
    if type(holo)=='table' then
        local route=holo.route or {}
        for i=2,#route do D.Line(vg,route[i-1][1],-route[i-1][2],route[i][1],-route[i][2],D.orange,3) end
        for _,p in ipairs(holo.marks or {}) do
            local color=(p[3]=='enemy' or p[3]=='boss') and {248,91,100,255} or D.orange
            nvgBeginPath(vg);nvgCircle(vg,p[1][1],-p[1][2],8);nvgFillColor(vg,D.Color(color));nvgFill(vg)
            D.Text(vg,p[2],p[1][1]+12,-p[1][2]-10,17,color)
        end
    elseif mode=='conquest' then
        for _,p in ipairs({{-95,165,'A'},{94,-140,'B'},{0,0,'C'}}) do D.Text(vg,p[3],p[1],p[2],32,D.orange) end
    elseif mode=='elimination' then
        nvgBeginPath(vg);nvgCircle(vg,0,0,36);nvgStrokeWidth(vg,3);nvgStrokeColor(vg,D.Color(D.orange));nvgStroke(vg)
    end
    nvgRestore(vg)
end
return M
