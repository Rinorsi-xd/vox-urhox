local data=require('core.ResourceData').Read('Story/Mission/Level1.json')
data.levels={data.level,require('core.ResourceData').Read('Story/Mission/Level2.json').level,require('core.ResourceData').Read('Story/Mission/Level3.json').level,
    require('core.ResourceData').Read('Story/Mission/Level4.json').level}
return data
