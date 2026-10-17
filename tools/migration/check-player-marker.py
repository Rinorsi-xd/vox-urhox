"""Run the real marker and Math3 in Lua 5.4; no engine process or graphics."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", ROOT.as_posix())
lua.execute(r'''
local Marker=require 'diagnostics.PlayerMarker'
local checks=0
local function Check(value,label) checks=checks+1;assert(value,label) end
local function Pure(value,seen)
    local kind=type(value)
    if kind=='table' then
        Check(not getmetatable(value),'plain result table')
        Check(not seen[value],'acyclic result')
        seen[value]=true
        for key,item in pairs(value) do Check(type(key)=='number' or type(key)=='string','primitive key');Pure(item,seen) end
        seen[value]=nil
    else Check(kind=='string' or kind=='boolean' or kind=='number' and value==value and math.abs(value)<math.huge,'finite primitive') end
end
Check(Marker.Capture(nil).reason=='no-app','no app')
Check(Marker.Capture({}).reason=='no-active-trial','no trial')
Check(Marker.Capture({trial={disposed=true}}).reason=='no-active-trial','disposed trial')
local body={translation=function()return {x=10,y=4,z=-20}end,rotation=function()return {x=0,y=0,z=0,w=1}end,center=function()return {x=10,y=5,z=-20}end,isValid=function()return true end}
local owner={type='ground',id=27,name='wall'};owner.ref=owner
local native={node={name='Hull27'},collisionLayer=1,collisionMask=65535}
local hit={dist=2,point={10,4,-15},normal={0,0,-1},collider=127,owner=owner,body={native=native}}
local calls={}
local space={Raycast=function(self,origin,direction,length,excluded)
    Check(excluded==body,'exclude real source body wrapper')
    calls[#calls+1]={origin=origin,direction=direction,length=length}
    return #calls%2==1 and hit or nil
end}
local app={mode='trial',trial={map={id='crater'},aimPoint={1,2,3},vehicle={body=body,spec={bounds={min={-2,-1,-3},max={2,2,6}}}},world={space=space}}}
local result=Marker.Capture(app)
Check(result.available and result.map=='crater' and result.space=='source-rh-metres','identity/source coordinates')
Check(not result.errors,'ordinary capture has no masked error')
Check(#calls==5 and #result.rays==5,'exactly five explicit queries')
Check(result.position[1]==10 and result.position[3]==-20 and result.rotation.w==1,'Body translation and quaternion contract')
Check(calls[1].origin[2]==5 and calls[1].direction[3]==1,'COM forward ray')
Check(math.abs(calls[2].origin[2]-3.35)<1e-9 and calls[2].origin[3]==-14.05,'front lower bound ray')
Check(calls[3].origin[1]==8.05 and calls[4].origin[1]==11.95,'lower flank rays')
Check(calls[5].direction[2]<0 and calls[5].direction[3]>0,'down-forward ray')
Check(result.rays[1].hit.collider==127 and result.rays[1].hit.nodeName=='Hull27','collider/node identity')
Check(result.rays[1].hit.owner.id==27 and result.rays[1].hit.owner.name=='wall','primitive owner identity')
Check(result.rays[2].hit==nil and result.rays[1].hit.body==nil,'miss and no retained native body')
Pure(result,{})
hit.point[1]=999;owner.name='changed';native.node.name='changed';app.trial.aimPoint[1]=999
Check(result.rays[1].hit.point[1]==10 and result.rays[1].hit.owner.name=='wall' and result.aimPoint[1]==1,'snapshot copies, no live references')
space.Raycast=function()error('expected ray failure')end
local failed=Marker.Capture(app)
Check(failed.available and #failed.rays==5 and #failed.errors==5,'per-query failure preserves remaining capture')
Pure(failed,{})
body.isValid=function()return false end
Check(Marker.Capture(app).reason=='invalid-body','invalid native wrapper never queried')
body.isValid=function()error('expected invalid state')end
local broken=Marker.Capture(app)
Check(not broken.available and broken.errors[1].stage=='capture','outer exception protection')
body.isValid=function()return true end
body.translation=function()return {x=0/0,y=0,z=0}end
Check(Marker.Capture(app).reason=='invalid-pose','nonfinite pose rejected')
body.translation=function()return {x=10,y=4,z=-20}end
body.rotation=function()return {x=0,y=math.sqrt(.5),z=0,w=math.sqrt(.5)}end
space.Raycast=function(self,origin,direction,length,excluded) Check(direction[1]>.9 and math.abs(direction[3])<1e-9,'source quaternion rotates forward');return nil end
local turned=Marker.Capture(app)
Check(turned.available and #turned.rays==5 and not turned.errors,'rotated pose capture')
Pure(turned,{})
PLAYER_MARKER_CHECKS=checks
''')
print(json.dumps({'status': 'PASS', 'checks': lua.globals().PLAYER_MARKER_CHECKS,
                  'boundary': 'Real production marker and Math3; controlled Body/Space contract mocks. No Native/Web run or performance claim.'}))
