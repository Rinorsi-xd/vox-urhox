local M={}
function M.Check(post)
    local Adaptive=require 'render.AdaptiveResolution'
    local a=Adaptive.New(true)
    for _=1,44 do a:Sample(1/30,true) end
    V.assert(a.scale==1,'resolution does not react before its sampling window')
    for _=1,3 do a:Sample(1/30,true) end
    V.assert(a.scale==.9,'sustained 30 FPS reduces resolution one step')
    for _=1,200 do a:Sample(1/30,true) end
    V.assert(a.scale==.7,'resolution has the original 70 percent floor')
    a:ResetWindow();for _=1,91 do a:Sample(1/60,true) end
    V.assert(a.scale==.75,'60 FPS recovers only five percent per window')
    a:ResetWindow();for _=1,110 do a:Sample(1/55,true) end
    V.assert(a.scale==.75,'50 to 58.5 FPS hysteresis avoids allocation oscillation')
    for _=1,180 do a:Sample(1/30,false) end
    a:Sample(2,true)
    V.assert(a.scale==.75 and a.frames==0,'background and resume stalls reset measurements')
    for _=1,650 do a:Sample(1/60,true) end
    V.assert(a.scale==1,'recovery never exceeds full quality')
    local w,h=a:Size(3840,2160,2,'high',false)
    V.assert(w==2880 and h==1620,'high quality caps source DPR at 1.5')
    w,h=a:Size(3840,2160,2,'medium',false)
    V.assert(w==1920 and h==1080,'lower quality uses source logical resolution')

    local width,height=graphics:GetWidth(),graphics:GetHeight()
    local first=post.graph;local fullBytes=first.colorBytes
    post.fixedResolution=false;post.adaptive.scale=.7
    -- Deterministic scale in the real production graph, independent of machine speed.
    post.adaptive.enabled=false
    coroutine.yield() -- Let the app's next Update own the allocation transaction.
    local rw,rh=post:RenderSize()
    V.assert(post.graph.width==rw and post.graph.height==rh and rw<width and rh<height,'real map source and filters resize together')
    V.assert(post.graph.passCount==29 and post.graph.colorBytes<fullBytes*.51,'70 percent scale retains effects with at least 49 percent fewer color bytes')
    V.assert(next(first.textures)==nil and next(first.scenes)==nil,'adaptive rebuild releases previous targets and scenes')
    V.assert(graphics:GetWidth()==width and graphics:GetHeight()==height,'adaptive render size leaves physical UI viewport unchanged')
    coroutine.yield();coroutine.yield()
    local im=Image:new();V.assert(graphics:TakeScreenShot(im),'capture actual reduced-resolution map')
    im:SavePNG('docs/migration/evidence/crater-native-adaptive.png');im:Dispose()
    local f=File('docs/migration/evidence/crater-adaptive-allocation.json',FILE_WRITE)
    f:WriteString(cjson.encode({full_width=width,full_height=height,width=rw,height=rh,full_color_bytes=fullBytes,
        scaled_color_bytes=post.graph.colorBytes,scale=.7,limits='Owned FP16 color buffers only; not total GPU memory or frame-time proof.'}));f:Dispose()
    local reduced=post.graph
    post.fixedResolution=true;post.adaptive.scale=1
    coroutine.yield()
    V.assert(post.graph.width==width and post.graph.height==height and next(reduced.textures)==nil,'restoring full resolution releases reduced targets')
    coroutine.yield()
end
return M
