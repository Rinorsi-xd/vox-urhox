-- Fractional CSS display advances from original font tables. Glyphs still use
-- NanoVG's atlas; contiguous equal-width characters stay in one text draw.
local M={}
local faces={};local ready=false
local cache={};local count=0
local function Init()
    if ready then return end
    local data=require('core.ResourceData').Read('UI/SourceFontMetrics.json')
    for name,source in pairs(data) do
        local face={advances={},kern={},units=source.units,ascent=source.ascent/source.units,descent=source.descent/source.units};faces[name]=face
        for _,group in ipairs(source.advances) do
            for _,cp in utf8.codes(group[2]) do face.advances[utf8.char(cp)]=group[1]/source.units end
        end
        for _,group in ipairs(source.kern) do
            for _,cp in utf8.codes(group[1]) do face.kern[utf8.char(cp)]=group[2] end
        end
    end
    local body=require('ui.SourceFonts').GetBodyFace()
    if body and body.fractional then faces['vox-body']=body end
    ready=true
end
local function Latin(cp) return cp<=255 or cp>=0x2010 and cp<=0x2027 or cp>=0x2030 and cp<=0x205e end
local function Kern(face,left,right)
    for _,group in ipairs(face.kern[left] or {}) do
        if group[2]:find(right,1,true) then return group[1]/face.units end
    end
    return 0
end
function M.Get(text,font)
    font=font or 'vox-display'
    if font~='vox-display' and font~='vox-tabular' and font~='vox-title' and font~='vox-body' then return nil end
    Init();local key=font..'\0'..text
    if not faces[font] then return nil end
    if cache[key]~=nil then return cache[key] or nil end
    local layout={groups={},width=0,count=0};local previous={}
    for _,cp in utf8.codes(text) do
        local char=utf8.char(cp);local name=font=='vox-body' and font or (font=='vox-title' or not Latin(cp)) and 'vox-title' or font
        local face=faces[name];local advance=face.GetAdvance and face:GetAdvance(char) or face.advances[char]
        -- Preserve the existing native fallback for missing/combining glyphs.
        if not advance then layout=false;break end
        local kern=previous.face==name and Kern(face,previous.char,char) or 0
        layout.width=layout.width+kern
        local group=layout.groups[#layout.groups]
        if group and group.face==name and group.advance==advance and kern==0 then
            group.text=group.text..char
        else
            layout.groups[#layout.groups+1]={face=name,text=char,first=char,advance=advance,x=layout.width,index=layout.count}
        end
        layout.width=layout.width+advance;layout.count=layout.count+1
        previous={face=name,char=char}
    end
    if #text<=2048 then
        if count>=256 then cache={};count=0 end
        cache[key]=layout;count=count+1
    end
    return layout or nil
end
function M.Advance(layout,size,spacing) return layout.width*size+layout.count*(spacing or 0) end
function M.Width(layout,size,spacing)
    -- CSS inline boxes round advance up to 1/64px. Retaining the raw EM float
    -- for center/right alignment can flip a glyph onto the next hinted pixel.
    return math.ceil(M.Advance(layout,size,spacing)*64-1e-8)/64
end
function M.Metrics(font,size)
    font=font or 'vox-display'
    if font~='vox-display' and font~='vox-tabular' and font~='vox-title' and font~='vox-body' then return nil end
    Init();local face=faces[font]
    if not face then return nil end
    return math.floor(face.ascent*size+.5),math.floor(face.descent*size+.5)
end
function M.Draw(vg,layout,x,y,size,spacing,font,atBaseline)
    -- CSS display runs share a baseline; TOP-aligning every fallback face
    -- independently shifts Chinese relative to Latin at larger font sizes.
    -- Chromium uses hhea metrics. This runtime uses Barlow's taller Windows
    -- ascent (1075 rather than 1000 EM), shifting a 40px title down by 3px.
    local primary=faces[(font=='vox-title' or font=='vox-body') and font or 'vox-display']
    nvgFontSize(vg,size);local baseline=atBaseline and y or y+math.floor(primary.ascent*size+.5)
    nvgTextAlign(vg,NVG_ALIGN_LEFT+NVG_ALIGN_BASELINE)
    for _,group in ipairs(layout.groups) do
        nvgFontFace(vg,group.face);nvgTextLetterSpacing(vg,0)
        local correction=group.advance*size-nvgTextBounds(vg,0,0,group.first)
        nvgTextLetterSpacing(vg,(spacing or 0)+correction)
        nvgText(vg,x+group.x*size+group.index*(spacing or 0),baseline,group.text)
    end
    nvgTextLetterSpacing(vg,0);nvgTextAlign(vg,NVG_ALIGN_LEFT+NVG_ALIGN_TOP)
end
return M
