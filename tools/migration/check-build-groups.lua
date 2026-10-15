local BP=require 'construction.Blueprint'
local Editor=require 'construction.BuildEditor'
local Surface=require 'render.JoinedSurface'
local History=require 'construction.EditHistory'
local Config=require 'Config'
local function Equal(a,b)
    if a==cjson.null then a=nil end;if b==cjson.null then b=nil end
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-5 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k,v in pairs(b) do if not Equal(a[k],v) then return false end end
    return true
end
local function Blueprint(specs) local bp=BP.New();for _,p in ipairs(specs) do bp:Add(p) end;return bp end
local function Canonical(bp)
    local out={};for _,p in ipairs(bp:List()) do local d=History.Snapshot(p);d.g=p.g;d.shellColor=p.shellColor or cjson.null;out[#out+1]=d end;return out
end
local function EdgeKeys(vertices,flat)
    local out={}
    local function Key(v) local t={};for a=1,3 do t[a]=math.floor(v[a]*10000+.5) end;return table.concat(t,',') end
    for i=1,#vertices,flat and 6 or 2 do
        local a=Key(flat and {vertices[i],vertices[i+1],vertices[i+2]} or vertices[i])
        local b=Key(flat and {vertices[i+3],vertices[i+4],vertices[i+5]} or vertices[i+1])
        out[#out+1]=a<b and a..'|'..b or b..'|'..a
    end;table.sort(out);return out
end
local function Rules()
    local file=assert(io.open('tools/migration/source-build-groups-fixtures.json'));local f=cjson.decode(file:read('*a'));file:close()
    local differences={};local checks=0
    local function Check(actual,expected,label)
        local same=Equal(actual,expected);V.assert(same,label)
        if not same and #differences<4 then differences[#differences+1]={label=label,actual=actual,expected=expected} end
        checks=checks+1;if checks%24==0 then coroutine.yield() end
    end
    for i,c in ipairs(f.selections) do
        local bp=Blueprint(c.specs);local e=Editor.New(bp);e.mirror=c.mirror;for _,id in ipairs(c.ids) do e.selection[id]=true end
        e:ToggleForm();Check(Canonical(bp),c.after,'source F selection '..i)
        local selected={};for id in pairs(e.selection) do selected[#selected+1]=id end;table.sort(selected);Check(selected,c.selected,'source F selected group closure '..i)
        V.assert(#e.history.undoStack==c.history,'source F transaction count '..i)
        e:Undo();Check(Canonical(bp),c.undo,'source F undo '..i);e:Redo();Check(Canonical(bp),c.redo,'source F redo '..i)
        e:ToggleForm();Check(Canonical(bp),c.second,'source second F split '..i)
    end
    for i,c in ipairs(f.removals) do
        local bp=Blueprint(c.specs);local e=Editor.New(bp);e.mirror=c.mirror;e:Remove({partId=c.id})
        Check(Canonical(bp),c.after,'source single-cell deletion splits remaining group '..i)
        e:Undo();Check(Canonical(bp),c.undo,'source deletion/group undo '..i);e:Redo();Check(Canonical(bp),c.redo,'source deletion/group redo '..i)
    end
    for i,c in ipairs(f.placements) do
        local bp=Blueprint(c.specs);local e=Editor.New(bp);e.mirror=c.mirror;e.joinNew=c.joinNew;e.autoColor=true;e.preview=c.pv
        if c.pv.mirror==cjson.null then e.preview.mirror=nil end
        e:Place();Check(Canonical(bp),c.after,'source connected new placement '..i)
        e:Undo();Check(Canonical(bp),c.undo,'source connected placement undo '..i);e:Redo();Check(Canonical(bp),c.redo,'source connected placement redo '..i)
    end
    for i,c in ipairs(f.surfaces) do
        local bp=Blueprint(c.specs);local out,groups=Surface.Build(bp:List())
        for slot,s in pairs(c.surfaces) do
            Check(out[slot].position,s.position,'source exact/cull vertices '..i..' '..slot)
            Check(out[slot].normal,s.normal,'source rotated normals '..i..' '..slot)
            local color={};for _,hex in ipairs(out[slot].colors) do local v=Config.HexLinear(hex);color[#color+1]=v.r;color[#color+1]=v.g;color[#color+1]=v.b end
            Check(color,s.color,'source linear vertex colors '..i..' '..slot)
        end
        for g,pos in pairs(groups) do Check(EdgeKeys(Surface.Edges(pos)),EdgeKeys(c.edges[tostring(g)],true),'source 20 degree group edges '..i..' '..g) end
    end
    for i,c in ipairs(f.decals) do
        local actual=require('render.LiveryProjection').Project(c.decal,c.sticker,Blueprint(c.specs):List())
        local positions,uv={},{}
        for _,v in ipairs(actual) do for a=1,3 do positions[#positions+1]=v.p[a] end;uv[#uv+1]=v.u;uv[#uv+1]=1-v.v end
        Check(positions,c.positions,'source projection on displayed joined surface '..i)
        Check(uv,c.uv,'source joined decal UV '..i)
    end
    local out=assert(io.open('.tmp/build-groups-differences.json','w'));out:write(cjson.encode(differences));out:close()
end
local app,view,bp,e,session,oldUpdate
local rules=coroutine.create(Rules)
for frame=5,74 do V.atFrame(frame,function()
    if coroutine.status(rules)~='dead' then local ok,err=coroutine.resume(rules);V.assert(ok,'source fixtures coroutine '..frame..': '..tostring(err)) end
end) end
local function Shot(name) local image=Image:new();V.assert(graphics:TakeScreenShot(image) and image:SavePNG('docs/migration/evidence/build-groups-'..name..'.png'),'native joined screenshot '..name);image:Dispose() end
V.atFrame(80,function()
    V.assert(coroutine.status(rules)=='dead','all frozen fixtures completed before rendering')
    app=VOX_HANGAR.app;app:EnterBuild();session=app.build;oldUpdate=session.Update;session.Update=function() end
    app.car:SetVisible(false);bp=BP.New()
    for row,type in ipairs({'cube','heavy','glass','neonCube'}) do for x=0,3 do bp:Add({type=type,pos={x,4,row*3},rot=0,color=0x32c5dd}) end end
    view=require('render.VehicleView').New(app.scene,'GroupVerification');view:Rebuild(bp)
    e=Editor.New(bp,function(ops) view:ApplyEdits(ops,bp) end);e.mirror=false;e:SelectAll();e:ToggleForm()
    local box=view:GetWorldBounds()
    V.assert(box:Defined() and math.abs(box.size.x-2)<1e-5 and math.abs(box.size.z-5)<1e-5,'joined-only world bounds include actual exterior geometry')
    local Preview=require('render.WorkshopPreview')
    local camera={maxDist=100,FlyTo=function() end}
    local preview=Preview.New({camera=camera});preview.view=view;preview:Frame()
    local radius=math.sqrt(box.size.x^2+box.size.y^2+box.size.z^2)*.5
    V.assert(preview.framing and math.abs(preview.framing.dist-(radius*2.3+3))<1e-5,'workshop frames joined-only vehicle from rendered geometry')
    preview.view=nil;preview:Dispose()
    local mission={player={bp=bp,Position=function() return {0,2.25,0} end},session={view={view=view}}}
    local size=require('story.Mission').CarSize(mission)
    V.assert(math.abs(size.w-2.5)<1e-5 and mission.sizeKey==bp:Size(),'story clearance includes joined-only vehicle width')
    view:UpdateIdle(0,0)
    V.assert(view.joined.rebuilds==1 and view.joined.vertices>0,'real group edit builds exterior geometry once')
    local rebuilds=view.joined.rebuilds;for i=1,120 do view:UpdateIdle(1/60,i/60) end
    V.assert(view.joined.rebuilds==rebuilds,'idle joined surfaces perform no per-frame geometry rebuild')
    for _,p in ipairs(bp:List()) do V.assert(view.visuals[p.id].joined and #view.visuals[p.id].models==0,'joined blocks release their ordinary model '..p.id) end
    local target=Vector3(-1.5*Config.CELL,4.5*Config.CELL,7.5*Config.CELL)
    session.camera.node.position=target+Vector3(12,10,-13);session.camera.node:LookAt(target)
    view:SetXray(false)
end)
V.atFrame(100,function()
    local ghost=require('render.BuildGhost').New(view.root)
    ghost:Refresh(e,false,true);local count=ghost.groupEdges[1] and #ghost.groupEdges[1] or 0
    V.assert(count>0 and #ghost.pool==0,'joined selection draws cached exterior edges without beveled ghost models')
    local edges=ghost.groupEdges;ghost:Refresh(e,false,true);V.assert(ghost.groupEdges==edges,'idle selection reuses group edge cache')
    ghost:Dispose()
    Shot('joined');view:SetXray(true)
    for _,mesh in pairs(view.joined.meshes) do V.assert(not mesh.geometry.castShadows,'joined xray disables shadows') end
    for _,line in pairs(view.joined.outlines) do V.assert(line.node.enabled,'joined xray exposes group exterior outline') end
end)
V.atFrame(120,function()
    Shot('xray');view:SetXray(false)
    local surface=view.joined.meshes.paint.vertices
    e:Remove({partId=2});view:UpdateIdle(0,0)
    V.assert(view.visuals[2]==nil and view.joined.meshes.paint.vertices~=surface,'single-cell destruction updates real exterior and exposed faces')
    e:Undo();view:UpdateIdle(0,0);V.assert(view.joined.meshes.paint.vertices==surface,'undo destruction restores culled joined mesh')
    e:SelectAll();e:ToggleForm();view:UpdateIdle(0,0)
    V.assert(not next(view.joined.parts) and not next(view.joined.meshes),'second F retires exact meshes and restores source ordinary blocks')
    for _,p in ipairs(bp:List()) do V.assert(not view.visuals[p.id].joined and #view.visuals[p.id].models>0,'ordinary native models restored '..p.id) end
    e:Undo();view:UpdateIdle(0,0);V.assert(next(view.joined.meshes)~=nil,'undo F restores real joined renderer')
    e:Redo();view:UpdateIdle(0,0);V.assert(next(view.joined.meshes)==nil,'redo F releases joined renderer')
    view:Dispose();app.car:SetVisible(true);session.Update=oldUpdate;app:ExitBuild()
    V.assert(not app.build,'joined render test releases scene and input ownership')
end)
