-- Actual native rendering and input at the same CSS-pixel size as the H5 Home.
local UI=require 'urhox-libs/UI'
local Hud=require 'ui.GarageHud'
local E=require 'urhox-libs/UI/Core/PointerEvent'
local Dialogs=require 'ui.GarageDialogs'
local app,s,store,menuUpdate
local w,h=1920,1080
local oldSize,oldW,oldH,oldScale=UI.GetViewportSize,UI.GetWidth,UI.GetHeight,UI.GetScale()
local function Click(widget)
    local r=widget:GetAbsoluteLayoutForHitTest()
    local data={x=(r.x+r.w/2)*UI.GetScale(),y=(r.y+r.h/2)*UI.GetScale(),pointerType='mouse',pointerId=95,button=MOUSEB_LEFT}
    UI.HandlePointerEvent(E.new('PointerDown',data));UI.HandlePointerEvent(E.new('PointerUp',data))
end
local function Bound()
    s=Hud.GetState();s.root:SetStyle({width=w,height=h});renderer:GetViewport(0):SetRect(IntRect(0,0,w,h))
end
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'native screenshot available')
    local crop=image:GetSubimage(IntRect(0,0,w,h));V.assert(crop:SavePNG('docs/migration/evidence/pc-source-'..name..'.png'),'saved '..name)
    crop:Dispose();image:Dispose()
end
local function Bounds(widget,x,y,width,height,name)
    local r=widget:GetAbsoluteLayoutForHitTest()
    V.assert(math.abs(r.x-x)<1 and math.abs(r.y-y)<1 and math.abs(r.w-width)<1 and math.abs(r.h-height)<1,name..' matches source CSS box')
end
V.atFrame(50,function()
    app=VOX_HANGAR.app;app.camera.autoSpin=false
    store=require('storage.BlueprintStore').New('vox-pc-source-test');app.store=store;app.bays.store=store;app.bays.active=false
    for i=1,20 do store:DeleteSlot(i) end
    app.bays.revision=app.bays.revision+1
    UI.SetScale(1);UI.GetViewportSize=function() return w,h end;UI.GetWidth=function() return w end;UI.GetHeight=function() return h end
    Hud.Update(0);Bound()
end)
V.atFrame(75,function()
    local D=require 'ui.SourceDraw';local vg=UI.GetNVGContext();D.Begin(vg);nvgSave(vg)
    local metrics={tabular={},spacing={}}
    local displayFile=assert(io.open('tools/migration/fixtures/source-display-widths.json','r'))
    local displayFixture=cjson.decode(displayFile:read('*a'));displayFile:close();metrics.display={}
    for _,row in ipairs(displayFixture.samples) do
        local actual=D.Width(vg,row.text,row.size,row.tabular and 'vox-tabular' or nil,row.spacing)
        V.assert(math.abs(actual-row.width)<.016,'original DOM display advance '..row.size..'px tracking '..row.spacing..' '..row.text)
        metrics.display[#metrics.display+1]={text=row.text,size=row.size,spacing=row.spacing,browser=row.width,native=actual}
    end
    local Typography=require 'ui.SourceTextLayout'
    local cachedTitle=Typography.Get('从零建造')
    V.assert(cachedTitle==Typography.Get('从零建造') and #cachedTitle.groups==1,'equal-width CJK title reuses one cached text draw')
    V.assert(Typography.Get('a'..utf8.char(0x301))==nil,'combining glyphs preserve native fallback')
    local fonts=require('ui.SourceFonts').Resolve()
    metrics.systemFonts=fonts
    if fonts.codeAdvance then
        V.assert(math.abs(D.Width(vg,'FKZC1:ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',12,'vox-code')-277.1015625)<.01,'Consolas blueprint width matches Chromium fractional advance')
        V.assert(math.abs(D.Width(vg,'ABC 0123456789',12,'vox-code')-92.3671875)<.01,'Consolas mixed ASCII width matches Chromium')
        local mixed=D.Width(vg,'AB中CD',12,'vox-code')
        V.assert(math.abs(mixed-D.Width(vg,'ABCD',12,'vox-code')-D.Width(vg,'中',12,'vox-code'))<.01,'CJK fallback advance is not squeezed by Consolas correction')
    end
    for _,size in ipairs({11,18,20,24,26,40,50}) do
        local row={};local zero=D.Width(vg,'0',size,'vox-tabular')
        for digit=0,9 do
            row[tostring(digit)]=D.Width(vg,tostring(digit),size,'vox-tabular')
            V.assert(math.abs(row[tostring(digit)]-zero)<.01,'native tabular '..size..'px digit '..digit)
        end
        V.assert(math.abs(zero-size*.483)<1,'tabular advance matches source font at '..size..'px')
        metrics.tabular[tostring(size)]=row
    end
    V.assert(D.Width(vg,'111',40)<D.Width(vg,'888',40),'normal display keeps source proportional digits')
    V.assert(D.Width(vg,'米秒',24,'vox-tabular')==D.Width(vg,'米秒',24),'tabular selector preserves source Chinese face')
    for _,sample in ipairs({'AV','012','车库','T3 战车'}) do
        local normal=D.Width(vg,sample,24);local tracked=D.Width(vg,sample,24,nil,1)
        V.assert(math.abs(tracked-normal-utf8.len(sample))<.01,'source CSS tracking advance '..sample)
        local drive=require 'ui.DriveDraw'
        V.assert(drive.Width(vg,sample,24,1)==tracked,'drive uses same measured tracked runs '..sample)
        metrics.spacing[sample]={normal=normal,tracked=tracked}
    end
    metrics.source_comparison={}
    for _,row in ipairs({{'717 / 1,000',26,113.78125},{'961 / 2,400 kg',18,97.421875},{'138 / 240',18,66.40625},{'3 / 4',18,31.640625}}) do
        metrics.source_comparison[#metrics.source_comparison+1]={text=row[1],size=row[2],browser=row[3],native=D.Width(vg,row[1],row[2],'vox-tabular')}
    end
    local f=assert(io.open('docs/migration/evidence/pc-font-metrics.json','w'));f:write(cjson.encode(metrics));f:close();nvgRestore(vg)
    Shot('home-1920');Bounds(s.nav,0,0,1920,60,'navigation');Bounds(s.info,28,82,380,990,'vehicle column')
    Bounds(s.cta,537,844,846,68,'three primary actions');Bounds(s.cards[1],68,930,212,126,'draft card')
    V.assert(#s.cards==1 and #s.previews.items==0,'draft has source placeholder; empty bays not instantiated')
    V.assert(not s.buttons.details and not s.buttons.rename,'no invented details or rename homepage actions')
    V.assert(s.buttons.save~=nil,'draft exposes source save-to-bay action')
    Click(s.buttons.new);V.assert(s.newOpen and Hud.IsBlocked(),'new vehicle opens source popover and gates camera')
    menuUpdate=s.menu.Update;s.menu.Update=function() end
    s.menu:SetOpen(true);menuUpdate(s.menu,0)
end)
V.atFrame(77,function()
    Shot('new-menu-entry-0');menuUpdate(s.menu,.05)
    V.assert(s.menu.entry.value>0 and s.menu.entry.value<1 and s.menu.props.translateY>0,'source menu entry is in progress after 50ms')
end)
V.atFrame(79,function() Shot('new-menu-entry-50');menuUpdate(s.menu,.15) end)
V.atFrame(83,function()
    Shot('new-menu');s.menu.Update=menuUpdate
    Bounds(s.menu,144,581.625,320,332.375,'original full-description menu')
    Bounds(s.menu.children[2],150,651.421875,308,95.390625,'original race-car menu item')
    V.assert(not s.menu.entry and s.menu.props.translateY==0,'source menu entry settles after 200ms')
    V.assert(not s.menu.layer.texture and s.menu.layer.bytes==0,'settled menu returns to direct drawing and releases entry targets')
    V.assert(#s.menu.children[2].description.lines==3 and #s.menu.children[3].description.lines==3,'full source vehicle descriptions fit in three lines')
    local f=assert(io.open('tools/migration/fixtures/source-menu-lines.json','r'))
    local source=cjson.decode(f:read('*a'));f:close()
    for i,lines in ipairs(source.rows) do
        local actual=s.menu.children[i].description.lines
        V.assert(#actual==#lines,'menu '..i..' line count matches original DOM ranges')
        for j,expected in ipairs(lines) do
            local pieces={};for _,run in ipairs(actual[j].runs) do pieces[#pieces+1]=run.text end
            V.assert(table.concat(pieces)==expected,'menu '..i..' line '..j..' matches original browser text')
        end
    end
    local cached=s.menu.children[2].description;s.menu.children[2]:Update(.12)
    V.assert(s.menu.children[2].description==cached,'menu hover does not remeasure text')
    Click(s.menu.children[4]);V.assert(not s.newOpen and s.dialog~=nil,'real menu import hit opens original import dialog')
    Dialogs.Close(s);Click(s.buttons.save)
    V.assert(app.bays.active==1,'source draft save uses existing slot storage')
end)
V.atFrame(104,function()
    Shot('saved-car');V.assert(#s.cards==1 and s.previews.items[1].ready,'saved bay uses actual vehicle render')
    Click(s.buttons.export);V.assert(s.dialog~=nil,'share opens working export dialog');Dialogs.Close(s)
    Click(s.buttons.battle);V.assert(s.tab=='battle' and not app.trial,'battle first opens source mode choice')
end)
V.atFrame(117,function()
    Shot('battle-1920');V.assert(not s.info:IsVisible() and not s.bayScroll:IsVisible(),'battle hides hangar stats and bays like H5')
    Bounds(s.cta,537,972,846,68,'battle actions');Click(s.page.children[4])
    V.assert(app.tier==4,'source T4 tab updates actual tier')
    Click(s.buttons.workshop)
end)
V.atFrame(130,function()
    Shot('workshop-1920');V.assert(#s.page.children==6,'workshop has source six cards and corresponding actions')
    local f=assert(io.open('tools/migration/fixtures/source-paragraphs-1920.json','r'));local fixture=cjson.decode(f:read('*a'));f:close()
    for i=1,6 do
        local paragraph=s.page.paragraphs[i];local actual=paragraph.layout.lines;local expected=fixture.samples[i].lines
        V.assert(#actual==#expected,'actual workshop '..i..' has original paragraph line count')
        for j,line in ipairs(actual) do
            local text='';for _,run in ipairs(line.runs) do text=text..run.text end
            V.assert(expected[j] and text==expected[j].text,'actual workshop '..i..' line '..j..' equals source DOM')
        end
        V.assert(paragraph.measurements==1,'actual workshop '..i..' reuses paragraph across rendered frames')
    end
    Click(s.buttons.shop)
end)
V.atFrame(141,function()
    Shot('shop-1920');Click(s.buttons.hangar);app.camera.autoSpin=false
    w,h=1440,900
end)
V.atFrame(157,function()
    Bound();V.assert(Hud.GetState()==s,'PC resizing retains owner')
    Click(s.buttons.new);s.menu:Update(.2)
end)
V.atFrame(160,function()
    Bounds(s.menu,144,401.625,320,332.375,'16:10 PC menu keeps source right and bottom anchors')
    Shot('new-menu-1440');s.SetNew(false)
end)
V.atFrame(166,function()
    Shot('home-1440');Bounds(s.cta,297,664,846,68,'16:10 PC action anchors')
    Click(s.buttons.settings);V.assert(s.dialog~=nil,'settings still interactive');Dialogs.Close(s)
    local root=s.root;Click(s.buttons.edit);V.assert(app.build~=nil and not root.node,'edit enters same application and releases homepage')
    app:ExitBuild();Bound()
end)
V.atFrame(186,function()
    V.assert(app.bays.active==1 and s.root.node~=nil,'return retains saved vehicle')
    Hud.Dispose();UI.GetViewportSize=oldSize;UI.GetWidth=oldW;UI.GetHeight=oldH;UI.SetScale(oldScale)
    store.pending=nil
    for i=1,20 do store:DeleteSlot(i) end
    for _,key in ipairs({'draft','garage-state'}) do for _,suffix in ipairs({'-a.json','-b.json'}) do local path=store.prefix..key..suffix;if fileSystem:FileExists(path) then fileSystem:Delete(path) end end end
    V.finish()
end)
