-- Match the original Windows PC CSS font stack using local installed fonts.
-- Neither system fonts nor derived caches belong in assets or the release pack.
local Collection=require 'core.SystemFontCollection'
local M={}
---@class SourceFontPaths
---@field body string
---@field bold string
---@field code string
---@field codeAdvance? number
---@field bodyMetrics? table
---@type SourceFontPaths?
local resolved=nil
---@type table?
local bodyFace=nil
---@type table?
local inlineCode=nil
---@type table?
local helpSymbol=nil
function M.Resolve()
    if resolved then return resolved end
    local paths={body='Fonts/MiSans-Regular.ttf',bold='Fonts/MiSans-Bold.ttf',code='Fonts/Anonymous Pro.ttf'}
    if GetPlatform()=='Windows' and os.getenv then
        local windows=os.getenv and os.getenv('SystemRoot') or 'C:/Windows'
        local fonts=windows:gsub('\\','/')..'/Fonts/'
        local cacheDir=fileSystem:GetAppPreferencesDir('VoxelCraft','SystemFonts')
        if cacheDir~='' and fileSystem:CreateDir(cacheDir) then
            paths.body=Collection.Prepare(fonts..'msyh.ttc',cacheDir..'yahei-ui-v1.ttc','Microsoft YaHei UI') or paths.body
            paths.bold=Collection.Prepare(fonts..'msyhbd.ttc',cacheDir..'yahei-ui-bold-v1.ttc','Microsoft YaHei UI') or paths.bold
        end
        if fileSystem:FileExists(fonts..'consola.ttf') then
            paths.code=fonts..'consola.ttf';paths.codeAdvance=Collection.MonoAdvance(paths.code)
        end
    end
    bodyFace=require('core.BodyFontMetrics').Load(paths.body)
    if bodyFace then paths.bodyMetrics={ascent=bodyFace.ascent,descent=bodyFace.descent,fractional=bodyFace.fractional,bufferBytes=bodyFace.bufferBytes} end
    resolved=paths
    print('[SourceFonts] body='..paths.body..'; code='..paths.code)
    return paths
end
function M.GetBodyFace() M.Resolve();return bodyFace end
-- The current H5 PC's missing U+21C4 glyph resolves to installed Noto Sans SC.
-- Keep this scoped to the measured help run; it is not a global fallback order.
function M.ResolveHelpSymbol()
    if helpSymbol then return helpSymbol end
    local path='Fonts/MiSans-Regular.ttf';local source=false
    if GetPlatform()=='Windows' and os.getenv then
        local windows=os.getenv and os.getenv('SystemRoot') or 'C:/Windows'
        local candidate=windows:gsub('\\','/')..'/Fonts/NotoSansSC-VF.ttf'
        if fileSystem:FileExists(candidate) then path=candidate;source=true end
    end
    helpSymbol={path=path}
    local metrics=require('core.BodyFontMetrics').Load(path)
    if metrics then
        helpSymbol.ascent=source and metrics.winAscent or metrics.ascent
        helpSymbol.descent=source and metrics.winDescent or metrics.descent
    end
    return helpSymbol
end
-- The original bare <code> uses the browser's Chinese monospace fallback,
-- unlike its explicitly styled Consolas textarea. Load it only when used.
function M.ResolveInlineCode()
    if inlineCode then return inlineCode end
    local path='Fonts/Anonymous Pro.ttf'
    local sourceFace=false
    if GetPlatform()=='Windows' and os.getenv then
        local windows=os.getenv and os.getenv('SystemRoot') or 'C:/Windows'
        local dir=fileSystem:GetAppPreferencesDir('VoxelCraft','SystemFonts')
        if dir~='' and fileSystem:CreateDir(dir) then
            local selected=Collection.Prepare(windows:gsub('\\','/')..'/Fonts/simsun.ttc',dir..'simsun-v1.ttc','SimSun')
            path=selected or path;sourceFace=selected~=nil
        end
    end
    inlineCode={path=path}
    local metrics=require('core.BodyFontMetrics').Load(path)
    if metrics then
        inlineCode.ascent=metrics.ascent;inlineCode.descent=metrics.descent
        if sourceFace then
            local advance=metrics:GetAdvance('0');local uniform=advance~=nil
            for cp=32,126 do if metrics:GetAdvance(utf8.char(cp))~=advance then uniform=false end end
            if uniform then inlineCode.advance=advance end
        end
    end
    return inlineCode
end
return M
