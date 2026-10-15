local Hud=require 'ui.GarageHud';local Box=require 'ui.MusicBox';local UI=require 'urhox-libs/UI'
local home,box,position,delayed,playerUpdate
local sandbox=false
for _,a in ipairs(GetArguments()) do if a=='-music-sandbox' then sandbox=true end end
local getenv,createFont=os.getenv,nvgCreateFont
local sourceBodyFonts,systemMusicFonts=0,0
if sandbox then
    -- Editor/Maker removes getenv; system font access may also be unavailable.
    os.getenv=nil
    nvgCreateFont=function(vg,name,path)
        if name=='vox-body' and path=='Fonts/VoxIndustrial-Bold.otf' then sourceBodyFonts=sourceBodyFonts+1 end
        if name=='vox-music-latin' then systemMusicFonts=systemMusicFonts+1 end
        return createFont(vg,name,path)
    end
end
local function Shot(name)
    local image=Image();V.assert(graphics:TakeScreenShot(image),'Music screenshot '..name)
    image:SavePNG('docs/migration/evidence/music-box-'..name..'-'..(VOX_HANGAR.app.musicTestCase or 'pc')..'.png');image:Dispose()
end
local function Click(widget) widget.props.onClick(widget) end
V.atFrame(65,function()
    local app=VOX_HANGAR.app
    for _,a in ipairs(GetArguments()) do app.musicTestCase=a:match('^%-music%-case=(.+)$') or app.musicTestCase end
    home=Hud.GetState();box=Box.Open(home)
    -- Validation runs hidden and must not depend on another desktop app's focus.
    playerUpdate=box.player.Update
    box.player.Update=function(self,dt,group) return playerUpdate(self,dt,group,false) end
    box.player:Update(0,'hangar',false)
    V.assert(#box.tracks==13,'Only original approved 13 tracks')
    V.assert(home.musicBox==box and Hud.IsBlocked(),'Music box blocks camera and home shortcuts')
    V.assert(UI.GetTopOverlay()==box.root,'Music owns overlay input')
    V.assert(box.root.props.onPointerDown(box.root,{x=0,y=0,button=MOUSEB_LEFT})==true,'Legacy WASM bubbled pointer without ID is supported')
    box.player:SetLibraryPlaylist(box.player.catalog.tracks);box.player:PlayTrack('hangar-01-workshop-floor')
    V.assert(box.player:Track() and box.player:Track().id=='hangar-01-workshop-floor','Original MP3 starts')
    V.assert(box.player.slots[box.player.current].sound.compressed,'MP3 remains compressed')
end)
V.atFrame(110,function()
    if sandbox then
        V.assert(os.getenv==nil,'Music UI renders with the sandbox getenv restriction')
        V.assert(nvgFindFont(UI.GetNVGContext(),'vox-body')>=0 and systemMusicFonts==0,'Music uses the original Industrial face, including Latin, without a separate system font')
    end
    V.assert(box.player:Position()>.1,'Audio position advances')
    box.player:SetPaused(true);position=box.player:Position();Shot('main')
    local l=box.layout;local r=l.rects
    V.assert(l.w==((box.cssWidth<=1000) and 720 or 880),'Original CSS popup width')
    V.assert(r.list[4]>0 and r.list[2]+r.list[4]<=r.transport[2],'List is bounded above transport')
    local shield=box.root:GetAbsoluteLayout();local viewportW,viewportH=UI.GetViewportSize()
    V.assert(math.abs(shield.w-viewportW)<=.5 and math.abs(shield.h-viewportH)<=.5,
        'Transparent input shield covers viewport within Yoga pixel rounding: '..cjson.encode(shield)..' viewport '..viewportW..'x'..viewportH)
end)
V.atFrame(115,function()
    if not sandbox then return end
    os.getenv=getenv
    local vg=nvgCreate(1);local previous=sourceBodyFonts
    require('ui.MusicDraw').Begin(vg)
    os.getenv=nil;nvgDelete(vg)
    V.assert(sourceBodyFonts>previous and systemMusicFonts==0,'System font access does not replace the original music typography')
end)
V.atFrame(185,function()
    if box and playerUpdate then box.player.Update=playerUpdate end
    if sandbox then os.getenv=getenv;nvgCreateFont=createFont end
end)
V.atFrame(140,function()
    V.assert(math.abs(box.player:Position()-position)<.06,'Paused music retains actual position')
    box.player:Resume();V.assert(box.player:Seek(8),'Seek supported for compressed MP3')
    box.player:Previous();V.assert(box.player:Position()<.2,'Previous restarts current after 3 seconds')
    box.player:SetPaused(true)
    box.player.favorites={};box.player:Favorite('hangar-01-workshop-floor')
    box.filter='favorites';Box.List(box);V.assert(#box.tracks==1,'Favorites filter')
    box.query='nothingmatches';Box.List(box);V.assert(#box.tracks==0,'Favorites search empty state')
    box.query='';box.filter='drive-combat';Box.List(box);V.assert(#box.tracks==4,'Original combat group only')
    box.query='VECTOR';Box.List(box);V.assert(#box.tracks==2,'Original English search ignores case')
    box.query='';box.filter='all';Box.List(box)
    Click(box.buttons.queue);V.assert(box.filter=='all' and box.query=='' and #box.tracks==13,'Locate resets filter and search')
    box.player:SetVolume(.5);V.assert(math.abs(require('audio.MusicPlayer').Gain(.5)-.100714)<.00001,'Original nonlinear -36dB music gain with .8 master')
    Click(box.buttons.mute);V.assert(box.player.volume==0,'Mute sets zero')
    Click(box.buttons.mute);V.assert(box.player.volume==.5,'Mute restores last nonzero level')
    box.player:SetPlayMode('sequence');Click(box.buttons.mode);Shot('mode-menu')
end)
V.atFrame(160,function()
    Click(box.options[3]);V.assert(box.player.playMode=='repeat' and not box.modeMenu:IsVisible(),'Original single-track repeat option')
    local saved=box.player.store:Read('music',function(v) return v.mode=='repeat' and v.volume==.5 and v.favorites['hangar-01-workshop-floor']==true end)
    V.assert(saved~=nil,'Favorites mode and volume saved through recoverable storage')
    box.player:SetPaused(true);Box.Close(home)
    V.assert(not home.musicBox and not Hud.IsBlocked(),'Closing restores home input')
    V.assert(box.player:Track().id=='hangar-01-workshop-floor' and box.player.continuationId=='hangar-01-workshop-floor','Closing preserves selected song through completion')
    V.assert(UI.GetTopOverlay()==nil,'Closing releases overlay')
    box=Box.Open(home);V.assert(box.player.favorites['hangar-01-workshop-floor'],'Favorite survives reopening')
    Box.Close(home)
    local backend={requests={},cancelled={}}
    function backend:Exists() return false end
    function backend:DownloadResources(paths,done) self.requests[#self.requests+1]={paths=paths,done=done};return #self.requests end
    function backend:CancelDownloadGroup(id) self.cancelled[id]=true end
    function backend:GetResource(kind,path) return cache:GetResource(kind,path) end
    function backend:ReleaseResource() end
    delayed=require('audio.MusicPlayer').New(nil,backend);delayed:SetLibraryMode(true);delayed:Update(0,'hangar',false)
    delayed:PlayTrack('hangar-01-workshop-floor');delayed:PlayTrack('hangar-02-circuit-ready')
    backend.requests[1].done(true,0)
    V.assert(backend.cancelled[1] and delayed.current==nil,'Rapid music change cancels and rejects old callback')
    backend.requests[2].done(true,0)
    V.assert(delayed:Track().id=='hangar-02-circuit-ready','Only latest delayed request commits')
    delayed:PlayTrack('hangar-03-service-interval');delayed:Dispose();backend.requests[3].done(true,0)
    V.assert(delayed.current==nil and delayed.disposed,'Disposed player ignores late download callback')
end)
