-- Predict the post-loading card without starting the live tutorial or saving.
local Rules=require 'story.TutorialRules'
local TouchMode=require 'controls.TouchMode'
local M={}
function M.Pick(tutorial,app)
    if not tutorial or tutorial.disposed or not tutorial.data or not tutorial.rules or not app or app.stopped then return end
    local rules=tutorial.rules
    if tutorial.initialized then
        if not rules.running then return end
    else
        local record={};for key,value in pairs(rules.record) do record[key]=value end
        rules=Rules.New(tutorial.data,record,nil)
        if not rules:Resume({}) and not app.isValidation and not rawget(_G,'VOX_SKIP_TUTORIAL')
            and not rules.record.done and not rules.record.skipped then rules:Start(1,nil,{}) end
        if not rules.running then return end
    end
    local spec=rules:StepSpec();local lines=spec and (TouchMode.Enabled() and spec.touchLines or spec.lines)
    local line=lines and lines[1];local who=line and line[1]
    if who~='nono' and who~='huhu' then return end
    local face=(line[3] or 'talk'):gsub('^'..who..'_','')
    -- The first card is typing: CommsPortrait's talking pose is authoritative.
    if who=='nono' or face=='smug' then face='talk' end
    return who,face
end
return M
