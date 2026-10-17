"""Compare actual Lua draw calls with the frozen H5 missile-search renderer."""
import hashlib
import json
import math
import re
import subprocess
import sys
import argparse
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

source=json.loads(subprocess.check_output(['node',str(ROOT/'tools/migration/missile-hud-scale-source.mjs')],cwd=ROOT,text=True,encoding='utf-8'))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
package.path='scripts/?.lua;'..package.path
package.preload['urhox-libs/UI/Widgets/Panel']=function()return {Extend=function()return{}end}end
package.preload['controls.TouchMode']=function()return {Compact=function()return cfg.compact end}end
package.preload['ui.ReticleNavigation']=function()return{}end
package.preload['ui.SourceDraw']=function()return {
 Begin=function()end, Color=function(c)return c end,
 Rect=function(_,x,y,w,h,c)draws[#draws+1]={kind='rect',x=x,y=y,w=w,h=h}end,
 Text=function()error('Unexpected legacy fallback text')end}end
local points={};local width=0
function nvgBeginPath()points={}end
function nvgMoveTo(_,x,y)points[#points+1]={x,y}end
function nvgLineTo(_,x,y)points[#points+1]={x,y}end
function nvgStrokeColor()end
function nvgStrokeWidth(_,w)width=w end
function nvgStroke()draws[#draws+1]={kind='path',points=points,width=width}end
graphics={GetDPR=function()return cfg.dpr end,GetWidth=function()return cfg.w end,GetHeight=function()return cfg.h end}
hud=require 'ui.MissileHud'
widget={GetAbsoluteLayout=function()return {x=0,y=0,w=cfg.w/cfg.uiScale,h=cfg.h/cfg.uiScale}end,
 session={pointer={captured=true},weapons={LockInfo=function()return info end},
 camera={GetCamera=function()return{fov=60}end},world={time=.35}},overlay={focus=true}}
function render()draws={};hud.Render(widget,{});return draws end
""")

def table(v):
    if isinstance(v,dict):return lua.table_from({k:table(x)for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(x)for x in v])
    return v

def close(a,b,message,tolerance=1e-7):
    assert abs(a-b)<=tolerance,f'{message}: {a} != {b}'

def numbers(text):return [float(v)for v in re.findall(r'-?\d+(?:\.\d+)?',text)]

def compare(c,dpr,ui_scale):
    # The same widget/module remains alive across all resize and DPR changes.
    lua.globals().cfg=table({'w':c['width']*dpr,'h':c['height']*dpr,'dpr':dpr,'uiScale':ui_scale,'compact':c['compact']})
    seek=c['seek']
    lua.globals().info=table({**seek,'box':c['angle']})
    actual=lua.globals().render()
    css=ui_scale/dpr
    k=c['k'];cx=c['width']/2;cy=c['height']/2
    # Read exact rendered source geometry rather than duplicating its scale formula.
    svg=c['svg']
    tick=re.search(r'<path class="zonet" d="([^"]+)" style="stroke-width:([\d.]+)"',svg)
    assert tick
    ticks=re.findall(r'M(-?[\d.]+) (-?[\d.]+)([vh])(-?[\d.]+)',tick.group(1))
    assert len(ticks)==36
    for n,(x,y,axis,length)in enumerate(ticks):
        p=actual[n+5]['points'];x=float(x);y=float(y);length=float(length)
        close(p[1][1]*css,x,'tick x',.051)
        close(p[1][2]*css,y,'tick y',.051)
        close(p[2][1]*css,x+(length if axis=='h' else 0),'tick end x',.101)
        close(p[2][2]*css,y+(length if axis=='v' else 0),'tick end y',.101)
        close(actual[n+5]['width']*css,float(tick.group(2)),'tick width',.051)
    zone=re.search(r'class="zone [^"]*" d="[^"]+" style="stroke-width:([\d.]+)"',svg)
    close(actual[1]['width']*css,float(zone.group(1)),'zone width',.051)
    scan=re.search(r'<path class="scan" d="M([\d. -]+)H([\d.-]+)" style="stroke-width:([\d.]+)"',svg)
    has_scan=c['phase']=='search'
    assert bool(scan)==has_scan
    expected_paths=41 if has_scan else 40
    assert len(actual)==expected_paths+2,'All source search elements retained'
    if has_scan:
        xy=numbers(scan.group(1));s=actual[41]
        close(s['points'][1][1]*css,xy[0],'scan start x',.051)
        close(s['points'][1][2]*css,xy[1],'scan y',.051)
        close(s['points'][2][1]*css,float(scan.group(2)),'scan end x',.051)
        close(s['width']*css,float(scan.group(3)),'scan width',.051)
    bars=re.findall(r'<path class="zbar(?: bg)?" d="M([\d. -]+)h([\d.-]+)" style="stroke-width:([\d.]+)"',svg)
    assert len(bars)==2
    for n,(xy,length,stroke)in enumerate(bars):
        rect=actual[expected_paths+n+1];xy=numbers(xy)
        close(rect['x']*css,xy[0],'bar x',.051)
        close(rect['y']*css,xy[1],'bar anchor y',.051)
        close(rect['w']*css,float(length),'bar length',.051)
        close(rect['h']*css,float(stroke),'bar thickness',.051)
    return {'viewport':[c['width'],c['height']],'compact':c['compact'],'dpr':dpr,'uiScale':ui_scale,
            'phase':c['phase'],'angle':c['angle'],'k':k,'drawCalls':len(actual)}

results=[compare(c,dpr,scale)for c in source['cases']for dpr in [1,2,3]for scale in [dpr,.75*dpr,1.5*dpr]]
# Mutations stay in memory and must fail the source-render comparison.
original=(ROOT/'scripts/ui/MissileHud.lua').read_text(encoding='utf-8')
negatives=[]
for name,old,new in [
 ('old-720p-scale','local scale=ReticleState.Layout(r.w,r.h).k','local scale=math.min(1,r.h/720)'),
 ('unscaled-ticks','c,1.1*scale','c,1'),
 ('unscaled-scan','{242,246,248,64},1.2*scale','{242,246,248,64},1'),
 ('unscaled-bar-offset','cy+box+26*scale','cy+box+26')]:
    assert old in original
    lua.execute("hud=assert(load(...,'@missile-scale-negative'))()",original.replace(old,new))
    try:compare(source['cases'][0],1,.75)
    except AssertionError as error:negatives.append({'name':name,'rejected':True,'reason':str(error)})
    else:raise AssertionError('Mutation incorrectly accepted: '+name)

paths=['scripts/ui/MissileHud.lua','scripts/ui/ReticleState.lua',
       'tools/migration/missile-hud-scale-source.mjs','tools/migration/check-missile-hud-scale.py']
report={'status':'PASS','baseline':source['baseline'],'cases':len(results),'sourceHashes':source['sourceHashes'],
 'hashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'negatives':negatives,'samples':results,
 'boundary':'Actual frozen H5 _seek and reticleScale, actual Lua MissileHud/ReticleState; NanoVG calls recorded through adapters. Same widget across resize/DPR/UIscale. No engine rendering, screenshots, FPS or mobile acceptance. Compact selection is supplied to both sides; device policy requires the separate compact integration check. Existing bracket shape/colors and bar center-versus-top styling are outside this scale fix.'}
parser=argparse.ArgumentParser()
parser.add_argument('--out',default='docs/migration/evidence/missile-hud-scale-2026-10-17.json')
args=parser.parse_args()
out=ROOT/args.out
if out.exists():raise FileExistsError('Preserve previous evidence; use --out with a fresh path')
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items()if k!='samples'},indent=2))
