local data=require('core.ResourceData').Read('Story/Mission/Level1.json')
local resultVoices=require('core.ResourceData').Read('Story/Mission/ResultVoices.json')
for id,voice in pairs(resultVoices.voices) do data.voices[id]=voice end
data.levels={data.level,require('core.ResourceData').Read('Story/Mission/Level2.json').level,require('core.ResourceData').Read('Story/Mission/Level3.json').level,
    require('core.ResourceData').Read('Story/Mission/Level4.json').level,require('core.ResourceData').Read('Story/Mission/Level5.json').level}
return data
