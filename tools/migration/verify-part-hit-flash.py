"""Actual frozen H5 HUD against actual Lua event/render consumers, no GPU."""
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

reference=json.loads(subprocess.check_output(['node','tools/migration/part-hit-flash-source.mjs'],text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
fixture=(ROOT/'tools/migration/check-restore-flash.lua').read_text(encoding='utf-8').split('local scenarios=0')[0]
factory=lua.execute(fixture+'''
function Node:GetChildren(recursive)
 local out={};for _,child in ipairs(self.children)do out[#out+1]=child
  if recursive then for _,descendant in ipairs(child:GetChildren(true))do out[#out+1]=descendant end end
 end;return out
end
function Node:SetEnabledRecursive(on)self.enabled=on;for _,child in ipairs(self:GetChildren(true))do child.enabled=on end end
local CreateComponent=Node.CreateComponent
function Node:CreateComponent(kind)local component=CreateComponent(self,kind);component.node=self;return component end
package.loaded['render.NodeVisibility']=nil
package.loaded['render.DriveView']={}
package.loaded['render.VehicleView']={}
package.loaded['render.WeaponView']={}
package.loaded['Config']={CELL=.5}
package.loaded['construction.Blueprint']={}
package.loaded['parts.Defs']={PARTS={}}
package.loaded['drive.VehicleSpec']={}
package.loaded['core.Math3']={}
local Car=require 'combat.CarUnit'
local Combat=require 'render.CombatView'
return function()
 local restore,enemy,view=fixture();restore:Dispose()
 for _,part in pairs(enemy.bp.parts) do part.type='cube' end
 local scene=setmetatable({children={}},Node)
 local combat=Combat.New(scene)
 local drive={view=view,Update=function()end,Dispose=function()end}
 view.UpdateIdle=function()end;view.UpdateWeaponEffects=function()end
 combat.units[enemy]=drive
 local player,ally={},{}
 local world={feedbackPlayer=player,time=0,viewEvents={},debris={events={}}}
 function world:RecordDamage()end
 setmetatable(enemy,{__index=Car});enemy.env=world
 local function Event(target,attacker,part,shield,time)
  world.time=time;world.attacker=attacker=='ally' and ally or player
  if attacker=='none' then world.attacker=nil end
  local victim=target=='player' and setmetatable({env=world},{__index=Car}) or enemy
  if target=='player' then world.feedbackPlayer=victim else world.feedbackPlayer=player end
  local id=type(part)=='number' and part or part=='missing' and 99 or 1;if part=='none' then id=nil end
  victim:RecordDamage(1,nil,{partId=id,shield=shield})
  local event=world.viewEvents[1]
  combat:Consume(world)
  return event
 end
 local function Counts() return created,freed end
 return {combat=combat,enemy=enemy,view=view,world=world,event=Event,counts=Counts,drive=drive}
end
''')
checks=0
def check(value,label):
    global checks
    assert value,label
    checks+=1

for case in reference['cases']:
    f=factory()
    f['event']('enemy','player','valid',False,0)
    state=f['combat']['hitFlash']['targets'][f['enemy']]
    initial=state['at']
    event=f['event'](case['target'],case['attacker'],case['part'],case['shield'],case['time'])
    after=f['combat']['hitFlash']['targets'][f['enemy']]
    did_flash=after['at']!=initial
    expected=bool(case['calls'])
    check(did_flash==expected,('H5 event parity',case,did_flash))
    if expected:
        item=after['flash']['items'][len(after['flash']['items'])]
        color=item['color']
        integer=case['calls'][0]['color']
        def linear(v):
            v=v/255
            return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
        check(all(abs(color[i+1]-linear((integer>>shift)&255))<1e-12 for i,shift in enumerate([16,8,0])),('color',case))
        check(item['pop']==False and case['calls'][0]['pop']==False,('nonpop',case))
    check(event['partId']==(None if case['part']=='none' else 99 if case['part']=='missing' else 1),'actual CarUnit preserves part id')
    check(event['shield']==case['shield'],'actual CarUnit preserves shield marker')
    check(len(f['world']['viewEvents'])==0,'actual CombatView consumes events before clearing')
    f['combat'].Dispose(f['combat'])

run_lifecycle=lua.eval('''function(f)
 local function Check(v,s)assert(v,s)end
 f.event('enemy','player','valid',false,0)
 local fx=f.combat.hitFlash.targets[f.enemy].flash
 local item=fx.items[1];local copy=item.copies[1];local node=item.node;local material=fx.material
 local created0
 local nativeScale=f.view.visuals[1].node.scale
 for i=1,100 do
  f.combat:Update(1,.081,{})
  f.event('enemy','player','valid',i%2==0,i*.081)
  if i==10 then created0=f.counts() end
 end
 Check(f.counts()==created0,'repeated hits reuse Model wrapper after overlap capacity warms')
 Check(#fx.items<=5 and #fx.pool<=8 and fx.material==material,'source overlapping snapshots remain bounded and share material')
 Check(f.view.visuals[1].node.scale==nativeScale,'nonpop never alters original scale')
 f.combat:Update(1,.35,{})
 Check(#fx.items==0 and #fx.pool==5 and not node.disposed,'expired shells retained in bounded pool')
 f.event('enemy','player','valid',true,9)
 Check(f.counts()==created0,'expired same-part hit reuses geometry')
 f.combat:Update(1,.35,{})
 f.view.visuals[1]=nil;f.combat:Update(1,0,{})
 Check(#fx.pool==0 and copy.disposed and node.disposed,'removed pooled part frees every copy/node')
 f.event('enemy','player','missing',false,10)
 Check(#fx.items==0,'removed part cannot create shell')
 f.combat:Dispose();f.combat:Dispose()
 Check(material.disposed,'owner material released')
 return 9
end''')
checks+=run_lifecycle(factory())
run_generation=lua.eval('''function(f,active,replaceDrive)
 f.event('enemy','player','valid',false,0)
 local fx=f.combat.hitFlash.targets[f.enemy].flash;local item=fx.items[1];local copy=item.copies[1]
 if not active then f.combat:Update(1,.35,{})end
 if replaceDrive then f.combat.units[f.enemy]=nil else f.view.visuals={}end
 f.combat.hitFlash:Update(0,f.combat.units)
 assert(f.combat.hitFlash.targets[f.enemy]==nil and fx.disposed and item.node.disposed and copy.disposed and next(fx.copyOwners)==nil,'view replacement/death retires active and pool')
 f.combat:Dispose();return 1
end''')
for active in [True,False]:
    for drive in [True,False]: checks+=run_generation(factory(),active,drive)

more_lifecycle=lua.eval('''function(f)
 local n=0;local function Check(v,s)assert(v,s);n=n+1 end
 f.event('enemy','player',3,true,0)
 local fx=f.combat.hitFlash.targets[f.enemy].flash;local joined=fx.items[1];local material=joined.material
 Check(joined.geometry~=nil and not joined.pop,'joined shape uses nonpop shell')
 Check(material.joined_color.x<1 and material.joined_color.z==1,'joined shield tint uniform')
 f.event('enemy','player',3,false,.081)
 local white=fx.items[2]
 Check(#fx.items==2 and joined.material==material and white.material.joined_color.x==1,'source overlapping joined shells retain their individual tint')
 local color=f.view.visuals[3].models[1].instanceColor
 Check(color==nil,'original part instance color never overwritten')
 local visibility=require 'render.NodeVisibility'
 f.view.root.enabled=false;fx:Update(0)
 Check(not fx.root.enabled and not joined.node.enabled,'hidden vehicle recursively hides shell')
 f.view.root.enabled=true;fx:Update(0)
 Check(fx.root.enabled and joined.node.enabled,'visible vehicle restores shell')
 f.view.visuals[3]=nil;fx:Update(0)
 Check(#fx.items==0 and joined.node.disposed and material.disposed,'active removed joined part released')
 f.event('enemy','player',1,false,.2);local item=fx.items[1]
 local snapshot=item.models[1].node.transforms
 f.view.visuals[1].node.rotation={changed=true};fx:Update(.01)
 Check(item.models[1].node.transforms==snapshot,'ongoing shell retains its source hit-pose snapshot')
 f.event('enemy','player',1,false,.3)
 local nextItem=fx.items[#fx.items]
 Check(nextItem~=item and nextItem.node.rotation==f.view.visuals[1].node.rotation and item.models[1].node.transforms==snapshot,'new hit snapshots current pose while old shell stays unchanged')
 local copy=item.copies[1];f.view.visuals[1]=nil;fx:Update(0)
 Check(copy.disposed and item.node.disposed and #fx.items==0,'active removed articulated part released')
 f.combat:Dispose();return n
end''')
checks+=more_lifecycle(factory())
pool_limit=lua.eval('''function(f)
 local prototype=f.view.visuals[2]
 for id=4,15 do
  f.enemy.bp.parts[id]={id=id,type='cube'}
  f.view.visuals[id]={node=prototype.node,data=prototype.data,models=prototype.models,joined=false}
 end
 local first
 for id=4,15 do
  f.event('enemy','player',id,false,id*.4)
  local fx=f.combat.hitFlash.targets[f.enemy].flash
  first=first or fx.items[1];fx:Update(.35)
  assert(#fx.pool<=8 and #fx.items==0,'idle shell pool bounded at eight')
 end
 assert(first.node.disposed,'oldest pooled shell evicted')
 local fx=f.combat.hitFlash.targets[f.enemy].flash
 f.combat:Dispose();assert(next(fx.copyOwners)==nil and #fx.pool==0,'pooled wrappers fully released')
 return 14
end''')
checks+=pool_limit(factory())

legacy_commit='9541dc59ef2f281cafa5126762a57550189e04dc'
legacy_path='scripts/combat/CarUnit.lua'
legacy_sha256='55de1c71f380feb803a0a053f56671708dbdf60e566a33346fd327ed73082712'
legacy_bytes=subprocess.check_output(['git','show',legacy_commit+':'+legacy_path])
assert hashlib.sha256(legacy_bytes).hexdigest()==legacy_sha256,'Pinned pre-fix CarUnit identity changed'
legacy_code=legacy_bytes.decode('utf-8')
lua.globals().LegacyCarSource=legacy_code
legacy=lua.execute('''
local Car=assert(load(LegacyCarSource,'@pre-fix:scripts/combat/CarUnit.lua'))()
local world={viewEvents={},RecordDamage=function()end}
local unit=setmetatable({env=world},{__index=Car})
unit:RecordDamage(1,nil,{partId=7,shield=true})
return world.viewEvents[1]
''')
check(legacy['partId'] is None and legacy['shield'] is None,'actual pinned pre-fix commit drops flash event fields')

# Execute production draw module, recording the actual selected fonts and sizes.
draw=LuaRuntime(unpack_returned_tuples=True)
render=draw.execute(r'''
package.path='scripts/?.lua;'..package.path
local texts={}
local D={}
function D.Text(vg,text,x,y,size,color,font,align,spacing)texts[#texts+1]={text=text,size=size,color=color,font=font,spacing=spacing,x=x,y=y}end
function D.Width(vg,text,size,font,spacing)return utf8.len(text)*(size*.5+(spacing or 0))end
function D.FontMetrics(vg,size)return size*.8,size*.2 end
package.loaded['ui.SourceDraw']=D
package.loaded['ui.ReticleDraw']={red={255,74,58,255},white={242,246,248,255}}
NVG_ALIGN_LEFT=1;NVG_ALIGN_CENTER=2
for _,name in ipairs({'nvgSave','nvgRestore','nvgGlobalAlpha','nvgTranslate','nvgScale'})do _G[name]=function()end end
local Draw=require 'ui.CombatFeedbackDraw'
return function(n,k)
 texts={};local size=(58+math.min(4,n-1)*6)*k
 Draw.Render(0,{low=0,repairAge=9,flash=0,hits={},cubes={},score={n=n,age=.5,bump=0,size=size,name='Source target',shown=300}},
 {k=k,cx=960*k,cy=540*k,width=1920*k,height=1080*k})
 return texts
end
''')
for k in [1,1.25,.6]:
    for html in reference['html']:
        n=html['n'];actual=render(n,k)
        label=re.search(r'<em[^>]*>(.*?)</em>',html['html'])[1]
        check(actual[2]['text']==label,'actual source連破 label')
        check(actual[2]['font']=='vox-title' and actual[3]['font']=='vox-title','source Industrial subtitle')
        check(actual[2]['size']==(24 if n>1 else 16)*k and actual[3]['size']==16*k,'separate source label/name sizes')
        check(actual[2]['color'][1]==255 and actual[2]['color'][2]==74 and actual[3]['color'][1]==242,'source red label and white name')
        check(actual[1]['font']=='vox-display','VoxNum Barlow mapping retained')

# Existing restore behavior stays independently exercised in a fresh runtime.
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tools/migration/check-restore-flash.lua')")
shader=(ROOT/'assets/Shaders/BLGL/RestoreFlash.shader').read_text()
check('depth_test_disabled' not in shader and 'depth_draw_never' in shader,'depth tests retained, no overlay wallhack')
paths=['scripts/combat/CarUnit.lua','scripts/render/CombatView.lua','scripts/render/RestoreFlash.lua','scripts/render/PartHitFlash.lua','scripts/ui/CombatFeedbackDraw.lua']
report={'pass':True,'checks':checks,'sourceCases':len(reference['cases']),'source':reference['source'],'baseline':reference['baseline'],
    'production':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
    'resources':{'assets/Shaders/BLGL/RestoreFlash.shader':hashlib.sha256((ROOT/'assets/Shaders/BLGL/RestoreFlash.shader').read_bytes()).hexdigest()},
    'restoreRegressionScenarios':10,
    'reproducedBeforeFix':{'commit':legacy_commit,'path':legacy_path,'sha256':legacy_sha256,
        'partId':legacy['partId'],'shield':legacy['shield']},
    'boundary':'Actual complete frozen H5 TestDrive._hud/CombatFeedback.kill and actual Lua CarUnit.RecordDamage, CombatView.Consume/Update, PartHitFlash, RestoreFlash, CombatFeedbackDraw. Native nodes/materials/models, driving and draw primitives are adapters. New hits snapshot current articulated pose; each existing shell retains that snapshot until refreshed/expired, as source paintFlash. Repeated same-part hits reuse bounded cached shells/model wrappers/materials. Source color/80ms strict boundary/non-pop and event/lifecycle contracts checked. No GPU/build/native/browser launch. Shader compilation, visible depth/glow, natural controls/combat and mobile performance remain OPEN; this increment is not in manifest-e266.'}
output=ROOT/'docs/migration/evidence/part-hit-flash-offline.json'
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
