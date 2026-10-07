-- One session/controller/HUD; each map supplies an authored scene and world.
return {
    trial={id='trial',name='试车场',scene='Scenes/TrialTrack.xml',world='drive.TrackWorld',assets='scene.TrackAssets',resources='Track/Resources.json'},
    crater={id='crater',name='坠舰陨坑',label='[debug]坠舰陨坑地图测试',scene='Scenes/Crater.xml',world='drive.CraterWorld',environment='scene.Crater',assets='scene.Crater',resources='Crater/Resources.json',prepareWorld='drive.CraterPhysics',
        webWarmup={{type='Texture2DArray',name='Crater/albedo.xml'},{type='Texture2DArray',name='Crater/nra.xml'}}},
}
