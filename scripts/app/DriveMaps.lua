-- One session/controller/HUD; each map supplies an authored scene and world.
local maps={
    trial={id='trial',name='试车场',scene='Scenes/TrialTrack.xml',world='drive.TrackWorld',assets='scene.TrackAssets',resources='Track/Resources.json',
        loadingArt='UI/Modes/test.jpg',loadingBrand='试车场',loadingSub='100 米加速道 · 坡道 · 靶场',
        loadingTips={'自由驾驶，熟悉操控和武器','靶车会逐块被打坏，看看你的火力','可以选任意档位'}},
    crater={id='crater',name='坠舰陨坑',label='[debug]坠舰陨坑地图测试',scene='Scenes/Crater.xml',world='drive.CraterWorld',environment='scene.Crater',assets='scene.Crater',resources='Crater/Resources.json',prepareWorld='drive.CraterPhysics',
        webWarmup={{type='Texture2DArray',name='Crater/albedo.xml'},{type='Texture2DArray',name='Crater/nra.xml'}},
        loadingArt='UI/Modes/crater.jpg',loadingBrand='自由探索',loadingSub='CV-07 ARGUS 坠毁现场 · 600 × 600 米',
        loadingTips={'开着自己的车在地图里随便转（没有敌人）','N 键传送到各个区域，Backspace 回出生点','熟悉路线、找狙击位和掩体'}},
}
local story={};for key,value in pairs(maps.crater) do story[key]=value end
story.id='story1';story.name='坠舰';story.storyLevel=1;story.loadingBrand='剧情模式 · 坠舰'
story.loadingSub='任务 01 · CRASH LANDING · CV-07 ARGUS'
story.loadingTips={'找到运输舰的黑匣子','在三个点停稳安装采集器','击退海盗侦察队，回到星际前途要塞'}
maps.story1=story
local convoy={};for key,value in pairs(maps.crater) do convoy[key]=value end
convoy.id='story2';convoy.name='物资车';convoy.storyLevel=2;convoy.loadingBrand='剧情模式 · 物资车'
convoy.loadingSub='任务 02 · SUPPLY RUN · CONVOY · 小运'
convoy.loadingTips={'护送无人运输车小运回要塞','离太远它会停下等你，海盗靠近会损耗运输车耐久','通过检查点后，运输车损毁可以从检查点重试'}
maps.story2=convoy
local siege={};for key,value in pairs(maps.crater) do siege[key]=value end
siege.id='story3';siege.name='围剿';siege.storyLevel=3;siege.loadingBrand='剧情模式 · 围剿'
siege.loadingSub='任务 03 · SIEGE · HOLD OUT · 2:00'
siege.loadingTips={'守住要塞两分钟，等待公司援军','护盾圈里维修战车，击退进入外圈的海盗','护盾被打穿后重启这一轮坚守'}
maps.story3=siege
local capture={};for key,value in pairs(maps.crater) do capture[key]=value end
capture.id='story4';capture.name='偷家';capture.storyLevel=4;capture.loadingBrand='剧情模式 · 偷家'
capture.loadingSub='任务 04 · TAKE IT BACK · RECLAIM A / B / C'
capture.loadingTips={'清掉圈附近的海盗，在圈里夺回采集器','顶住反扑后，按住 G 擦掉涂鸦','狐狐的小狐号受损后会撤退'}
maps.story4=capture
return maps
