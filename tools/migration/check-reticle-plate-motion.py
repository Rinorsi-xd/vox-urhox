"""Compare real Lua target-plate draw calls with the frozen H5 target renderer."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

node_source = r"""
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const b=JSON.parse(fs.readFileSync('docs/migration/outgame-baseline.json','utf8'));
const name='shared/ui/reticle.js',file=path.join(b.snapshot,name);
const hash=createHash('sha256').update(fs.readFileSync(file)).digest('hex');
if(hash!==b.files[name].sha256)throw Error('Frozen target source mismatch');
const sourceText=fs.readFileSync(file,'utf8');
const seekLayer=sourceText.indexOf('<g data-seek>'),targetLayer=sourceText.indexOf('<g data-target>');
if(seekLayer<0||targetLayer<0||seekLayer>=targetLayer)throw Error('Frozen seek/target layer changed');
const {MechReticle}=await import(pathToFileURL(file));
const cases=[];
for(const [w,h,k]of[[1920,1080,1],[1600,900,5/6],[2560,1440,4/3],[2400,1080,1],[960,432,.4]])
 for(const missile of[false,true])for(const progress of[.25,.5,.75,1])for(const [fx,fy]of[[.2,.3],[.5,.5],[.8,.7]]){
  const host={innerHTML:''},ref={};
  const s={k,w,h,cx:w/2,cy:h/2,q:()=>host,acq:{ref,t0:0},_ghost:()=>.8};
  const target={ref,x:w*fx,y:h*fy,size:180*k,name:'TARGET',dist:185.4,health:.6,arms:3};
  const seek=missile?{box:220*k,progress,locked:progress===1}:null;
  MechReticle.prototype._target.call(s,target,progress*420,seek);
  const line=host.innerHTML.match(/<path class="lead" d="M([\d. -]+)L([\d. -]+)H([\d.-]+)"/);
  if(!line)throw Error('Target plate absent');
  const pair=x=>x.split(' ').map(Number);
  const a=pair(line[1]),z=pair(line[2]);
  cases.push({w,h,k,missile,progress,x:target.x,y:target.y,half:target.size/2,
   e:(s.tbox.w/2-(missile?Math.max(seek.box,target.size/2):target.size/2*2.6))/(target.size/2-(missile?Math.max(seek.box,target.size/2):target.size/2*2.6)),
   line:[...a,...z],end:Number(line[3])});
 }
console.log(JSON.stringify({baseline:b.commit,hash,cases}));
"""
source = json.loads(subprocess.check_output(
    ['node', '--input-type=module', '-e', node_source], cwd=ROOT, text=True, encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
package.path='scripts/?.lua;'..package.path
package.loaded['urhox-libs/UI']={}
package.loaded['ui.SourceDraw']={
 Line=function(_,x,y,ex,ey)lines[#lines+1]={x,y,ex,ey}end}
package.loaded['ui.ReticleDraw']={Text=function()end,Poly=function()end,Width=function()return 40 end}
package.loaded['ui.ReticleState']={}
package.loaded['ui.ReticleFocus']={}
function nvgSave()end
function nvgRestore()end
function nvgGlobalAlpha()end
target=require 'ui.ReticleTarget'
function run(c)
 lines={}
 target.Plate({}, {session={world={time=1}}}, {k=c.k,cx=c.w/2,cy=c.h/2},
  {x=c.x,y=c.y,half=c.half,missile=c.missile,hp=.6,ghost=.8,distance=185.4,name='TARGET',arms=3},c.e)
 return lines
end
""")

def compare(case):
    actual = lua.globals().run(lua.table_from(case))
    assert len(actual) == 3
    for index, want in enumerate(case['line'], 1):
        assert abs(actual[1][index] - want) < .051, (case, index, actual[1][index], want)
    assert abs(actual[2][3] - case['end']) < .051

for case in source['cases']:
    compare(case)

layer_cases = lua.execute("""
local function Noop()end
local function Widget(p)
 local w={props=p or {},children={},node=true}
 function w:AddChild(c)self.children[#self.children+1]=c end
 function w:RemoveChild(c)for i,v in ipairs(self.children)do if v==c then table.remove(self.children,i);return end end end
 function w:SetVisible(v)self.visible=v end
 function w:SetStyle(p)for k,v in pairs(p)do self.props[k]=v end end
 w.Refresh=Noop;w.Destroy=Noop
 return w
end
local function Factory()return setmetatable({},{__call=function(_,p)return Widget(p)end})end
local root
package.loaded['urhox-libs/UI']={Panel=Widget,GetViewportSize=function()return 1920,1080 end,
 SetRoot=function(r)root=r end,GetRoot=function()return root end}
package.loaded['controls.TouchMode']={Apply=Noop}
package.loaded['ui.VoxTheme']={TrimThumbnails=Noop}
for _,n in ipairs({'DriveChrome','DriveMeter','DriveDetails','MechReticle','MissileHud','MvpShow','SalvageCinematics'})do package.loaded['ui.'..n]=Factory()end
for _,n in ipairs({'ResetProgress','SniperThreat','MatchHud','EndlessHud','MissionHud','BossHud','SalvageRunHud'})do
 package.loaded['ui.'..n]={Attach=function()return {Update=Noop,Dispose=Noop}end}
end
package.loaded['ui.DriveControls']={Create=function(_,r)local w=Widget();r:AddChild(w);return {playfield=w,root=w,Clear=Noop,Update=Noop}end}
package.loaded['ui.GameSettings']={Attach=function()return Widget()end}
package.loaded['ui.DriveReadouts']={New=function()return {SetVisible=Noop,Tick=Noop,Refresh=Noop}end}
package.loaded['ui.ReticleState']={Update=Noop}
package.loaded['ui.DriveOverlay']={New=function(_,r)local w=Widget();r:AddChild(w);return {layer=w,Update=Noop,aimState='ok'}end}
local Hud=require 'ui.DriveHud'
local count=0
for _,mode in ipairs({'practice','battle','endless','story','salvage'})do
 for _,captured in ipairs({false,true})do
  local group={kind='mg',weapons={{stats={}}}}
  local s={map={id='crater'},vehicle={},pointer={captured=captured},world={},
   weapons={groups={group},Group=function()return group end,Readiness=function()return 1 end}}
  if mode=='battle' then s.battle={rules={state='live'}}
  elseif mode=='endless' then s.endless={rules={},run={state='live'}}
  elseif mode=='story' then s.story={rules={}}
  elseif mode=='salvage' then s.salvage={cine={}}end
  local h=Hud.Create(s);local seeker,targetLayer
  for i,c in ipairs(h.root.children)do if c==h.missile then seeker=i end;if c==h.overlay.layer then targetLayer=i end end
  assert(seeker and targetLayer and seeker<targetLayer,'Frozen H5 seeker must draw before target')
  assert(h.missile.overlay==h.overlay,'Seeker retains final target reference')
  h.Dispose();count=count+1
 end
end
return count
""")

original = (ROOT / 'scripts/ui/ReticleTarget.lua').read_text(encoding='utf-8')
negative = original.replace('cx+f.half+22*k', 'f.x+f.half+22*k').replace('cy-f.half*.8-16*k', 'f.y-f.half*.8-16*k')
assert negative != original
lua.execute("target=assert(load(...,'@plate-motion-negative'))()", negative)
try:
    compare(next(c for c in source['cases'] if c['missile'] and c['progress'] == .25))
except AssertionError:
    rejected = True
else:
    raise AssertionError('Old fixed target center was incorrectly accepted')

report={'status':'PASS','baseline':source['baseline'],'sourceSha256':source['hash'],
    'cases':len(source['cases']),'hudLayerCases':layer_cases,'oldFixedCenterRejected':rejected,
    'hashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
        ['scripts/ui/ReticleTarget.lua','scripts/ui/DriveHud.lua','tools/migration/check-reticle-plate-motion.py']},
    'boundary':'Real frozen H5 _target and actual Lua Plate through NanoVG call adapters, actual DriveHud.Create in five modes with released/captured pointer. No GPU pixels, gameplay or performance measurement.'}
parser=argparse.ArgumentParser()
parser.add_argument('--out')
args=parser.parse_args()
if args.out:
    out=ROOT/args.out
    if out.exists():raise FileExistsError('Preserve previous evidence; use a fresh --out path')
    out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
