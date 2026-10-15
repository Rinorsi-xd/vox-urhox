local Hud=require 'ui.GarageHud'
local Data=require 'construction.LiveryData'
local Project=require 'render.LiveryProjection'
local BP=require 'construction.Blueprint'
local Code=require 'storage.BlueprintCode'
local page=false
local original={}
local function Shot(name)
    local image=Image:new();V.assert(graphics:TakeScreenShot(image),'Screenshot '..name)
    image:SavePNG('docs/migration/evidence/livery-native-'..name..'.png');image:Dispose()
end
V.atFrame(65,function()
    local app=VOX_HANGAR.app;original=Data.Clone(app.blueprint.livery)
    V.assert(#Data.Catalog().list==27,'Original catalog contains 27 stickers')
    local file=File('docs/migration/evidence/source-livery-projection.json',FILE_READ)
    local fixtures=cjson.decode(file:ReadString());file:Dispose()
    for i,fixture in ipairs(fixtures) do
        local actual=Project.Project(fixture.decal,Data.Catalog().byId[fixture.decal.s],{fixture.part})
        V.assert(#actual*3==#fixture.positions,'Original projection vertex count '..i)
        local expectedKeys,actualKeys={},{}
        for j,v in ipairs(actual) do
            actualKeys[j]=string.format('%.4f,%.4f,%.4f,%.4f,%.4f',v.p[1]+.000001,v.p[2]+.000001,v.p[3]+.000001,v.u+.000001,v.v+.000001)
        end
        for j=1,#fixture.positions//3 do
            expectedKeys[j]=string.format('%.4f,%.4f,%.4f,%.4f,%.4f',fixture.positions[j*3-2]+.000001,fixture.positions[j*3-1]+.000001,fixture.positions[j*3]+.000001,fixture.uv[j*2-1]+.000001,1-fixture.uv[j*2]+.000001)
        end
        table.sort(actualKeys);table.sort(expectedKeys)
        V.assert(table.concat(actualKeys,'|')==table.concat(expectedKeys,'|'),'Original geometry and UV parity '..i)
    end
    app.blueprint.livery={};app.car.livery:Set({});Hud.GetState().SetTab('livery')
end)
V.atFrame(85,function()
    page=Hud.GetState().livery;local app=page.app
    V.assert(page~=nil and #page.stickers==7,'Original character catalog mounted')
    Shot('empty')
    local parts=app.blueprint:List();local fixed=false
    for _,p in ipairs(parts) do if require('render.LiveryModel').Fixed(p) then fixed=p;break end end
    V.assert(fixed~=false,'Actual vehicle contains fixed parts')
    local d={s='burst',p={fixed.pos[1],fixed.pos[2]+1,fixed.pos[3]},n={0,1,0},r=0,w=3,c={0xff5050,0xffd23f}}
    local vertices=Project.Project(d,Data.Catalog().byId.burst,Project.Near(d,Data.Catalog().byId.burst,parts))
    V.assert(#vertices>0 and #vertices%3==0,'Native model projection creates triangles')
    local clipped=true;for _,v in ipairs(vertices) do if v.u<-.00001 or v.u>1.00001 or v.v<-.00001 or v.v>1.00001 then clipped=false end end
    V.assert(clipped,'Projected UV is clipped to source sticker')
    page.session:Pick('burst');page.session:Place({p=d.p,n=d.n})
    V.assert(#page.session:List()==1 and page.session.sel==1,'Place selects original sticker')
    V.assert(not page.session.pick,'Place releases held sticker')
end)
V.atFrame(100,function() page.session:Edit(function(d) d.c[1]=0x123456 end,true) end)
V.atFrame(105,function()
    local count=0;for _ in pairs(page.thumbnails.items) do count=count+1 end
    V.assert(count>0,'Custom color renders a recolored source thumbnail')
    Shot('custom-color')
end)
V.atFrame(110,function()
    local session=page.session;local mesh=page.app.car.livery.meshes[1]
    V.assert(mesh~=nil and #mesh.vertices>0,'Native decal mesh and material are ready')
    V.assert(mesh.material~=nil,'Surface material exists')
    local home=Hud.GetState();V.assert(home.livery==page,'Bay revision preserves live page session')
    V.assert(home.revision==page.app.bays.revision,'Live session acknowledges blueprint revisions without rebuilding hidden home')
    V.assert(page.propHeight==362.9375,'Original two-color selected properties height')
    Shot('selected')
    session:Edit(function(d) d.c[1]=0x3fd0ff end,true);page.app.car.livery:Update()
    V.assert(page.app.car.livery.meshes[1]==mesh,'Changing color reuses projected geometry')
    session:Edit(function(d) d.p[1]=4 end,true);session:Mirror()
    V.assert(#session:List()==2 and session:Twin(1)==2,'Mirror pairs source data')
    V.assert(session:List()[2].p[1]==-4,'Mirror follows source X coordinate')
    session:Edit(function(d) d.w=5;d.r=.5 end,true)
    V.assert(session:List()[2].w==5 and session:List()[2].r==-.5,'Pair shares size and opposite rotation')
    local saved=Code.Decode(Code.Encode(page.app.blueprint:ToTable()))
    local restored=BP.New():Load(saved)
    V.assert(#restored.livery==2 and restored.livery[1].w==5,'FKZC1 and blueprint load retain decal data')
    local store=require('storage.BlueprintStore').New('vox-livery-test')
    local bays=require('construction.Garage').New(restored,store,function(data) restored:Load(data);return true end,false)
    V.assert(bays:Save(1),'Dedicated test bay saves decal blueprint')
    local edit=require('construction.LiverySession').New({blueprint=restored,bays=bays,car={livery={Set=function() end,SetPreview=function() end}},toasts=page.app.toasts})
    edit:Select(1);edit:Edit(function(d) d.w=6 end,true);edit:Dispose()
    local loaded=BP.New():Load(store:LoadSlot(1))
    V.assert(#loaded.livery==2 and loaded.livery[1].w==6 and loaded.livery[2].w==6,'Leaving session saves paired decals to active bay')
    V.assert(store:DeleteSlot(1),'Dedicated test bay is removed')
    session:Remove();V.assert(#session:List()==0,'Remove deletes symmetry pair')
    session:Undo();V.assert(#session:List()==2,'Undo restores symmetry pair')
    session:Undo(true);V.assert(#session:List()==0,'Redo deletes symmetry pair')
    session:Undo();session:Clear();session:Undo();V.assert(#session:List()==2,'Clear has independent undo')
    session:Apply(original);session:Record();home.SetTab('hangar')
end)
V.atFrame(135,function()
    V.assert(Hud.GetState().livery==nil,'Leaving disposes page owner')
    V.assert(not page.session.active,'Leaving closes edit session')
    V.assert(page.app.car.livery.preview==nil or page.app.car.livery.preview==false,'Leaving releases placement preview')
    Hud.GetState().SetTab('livery')
end)
V.atFrame(155,function()
    V.assert(Hud.GetState().livery~=page,'Reenter creates a fresh independent history')
    Hud.GetState().SetTab('hangar')
end)
