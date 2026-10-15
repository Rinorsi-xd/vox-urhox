"""Compile the frozen EnginePit export using its shared, byte-equal crater hooks."""
from pathlib import Path
import copy
import hashlib
import json
import math
import shutil
import struct
import xml.etree.ElementTree as E
from PIL import Image
from crater_layout import build as partition

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/EnginePit'
SOURCE=ROOT/'tools/migration/engine-pit-source'
M=json.loads((SOURCE/'Manifest.json').read_text('utf-8'))
assert json.loads((SOURCE/'ShaderSources.json').read_text('utf-8'))==json.loads((ROOT/'tools/migration/crater-source/ShaderSources.json').read_text('utf-8')), 'Source shader hooks differ; port them before reusing'
SH=ROOT/'assets/Shaders/BLGL/EnginePit';SH.mkdir(parents=True,exist_ok=True)
shared=ROOT/'assets/Shaders/BLGL/Crater'
def xml(path,root):
    E.indent(root);E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
def attr(root,name,value): E.SubElement(root,'attribute',name=name,value=str(value))
def param(root,name,value):
    args={'name':name,'value':' '.join(map(str,value)) if isinstance(value,list) else str(value)}
    if not isinstance(value,list):args['type']='Float'
    E.SubElement(root,'parameter',**args)
def tex(root,name,path,kind='Texture2D'): E.SubElement(root,'surfacetexture',name=name,texture=path,type=kind)

# EnginePit exceeds the crater's encoded height range. Preserve its range as a
# material uniform rather than saturating the outside terraces to 192 metres.
heights=M['layout']['terrain']['heights'];n=M['layout']['terrain']['n']
lo,span=math.floor(min(heights)),math.ceil(max(heights))-math.floor(min(heights))
map_shader=(shared/'Map.shaderinc').read_text('utf-8')
old='/65535.0*256.0-64.0';assert old in map_shader
map_shader=map_shader.replace(old,'/65535.0*height_range.y+height_range.x')
map_shader='uniform vec2 height_range=vec2(-64.0,256.0);\n'+map_shader
for name in ('Fog.shaderinc','DirectLight.shaderinc'): shutil.copyfile(shared/name,SH/name)
(SH/'Map.shaderinc').write_text(map_shader,encoding='utf-8')
for i,d in enumerate(M['materials'],1):
    root=E.Element('material');kind=d['kind']
    shader={'terrain':'Terrain','far':'Far','glow':'Glow','fx':'Fx','shield':'Fx','scatter':'Scatter'}.get(kind)
    if shader:
        shader_path='Shaders/BLGL/Crater/'+shader+'.shader'
    else:
        shader='Map-'+('-'.join(sorted(d['defines'])) or 'plain')
        (SH/(shader+'.shader')).write_text('shader_type spatial;\nrender_mode shading_model_pbr,cull_disabled;\n'+''.join('#define '+key+'\n' for key in d['defines'])+'#include "Map.shaderinc"\n',encoding='utf-8')
        shader_path='Shaders/BLGL/EnginePit/'+shader+'.shader'
    E.SubElement(root,'surfaceshader',name=shader_path)
    for key,value in {'tint':d['color']+[d['opacity']], 'roughness':d['rough'],'metalness':d['metal'],'alpha_cut':d['alphaTest'],'emission':[v*d['emissionStrength'] for v in d['emission']],**d['uniforms']}.items():param(root,key,value)
    for key,value in d['textures'].items():tex(root,{'map':'albedo_map','normal':'normal_map'}.get(key,key),value)
    if kind=='scatter':param(root,'normal_scale',d['normalScale'])
    if kind in ('terrain','far'):
        tex(root,'tAlb','Crater/albedo.xml','Texture2DArray');tex(root,'tNra','Crater/nra.xml','Texture2DArray');tex(root,'tGround',M['ground'])
        param(root,'uGroundHalf',500)
    elif kind not in ('scatter','glow','fx','shield'):
        tex(root,'tTerrA','Crater/albedo.xml','Texture2DArray');tex(root,'tTerrN','Crater/nra.xml','Texture2DArray');tex(root,'tHeight','EnginePit/height.png');param(root,'height_range',[lo,span])
    if kind not in ('scatter','glow','fx','shield'):tex(root,'craterDFG','Crater/dfg.png')
    if kind not in ('terrain','far','scatter'):
        factor,units=(-2,-4) if kind in ('glow','fx') else ((-4,-16) if 'MAP_NOSAND' in d['defines'] else (-1,-2))
        E.SubElement(root,'depthbias',constant=str(units/(2**24)),slopescaled=str(factor))
    xml(OUT/f'material-{i}.xml',root)
image=Image.new('RGB',(n+1,n+1));pixels=image.load()
for x in range(n+1):
    for z in range(n+1):
        value=round((heights[x*(n+1)+z]-lo)/span*65535);pixels[x,z]=(value//256,value%256,0)
image.save(OUT/'height.png')
shutil.copyfile(OUT/'texture-0.png',OUT/'texture-0.bin')
visual=OUT/'VisualHeight.bin';raw=visual.read_bytes()
if raw[:4]!=b'VHF1': visual.write_bytes(struct.pack('<4sI3f',b'VHF1',n,-500,-500,2)+raw)
assert visual.stat().st_size==20+(n+1)**2*4
layout=copy.deepcopy(M['layout']);layout['blocks']=[]
for d in M['colliders']:
    q=d['q'];x,y,z,w=q
    rot=[math.atan2(2*(w*x+y*z),1-2*(x*x+y*y)),math.asin(max(-1,min(1,2*(w*y-z*x)))),math.atan2(2*(w*z+x*y),1-2*(y*y+z*z))]
    b={'pos':d['pos'],'rot':rot,'rotation':q,'friction':d.get('friction',.8)}
    if d.get('group'):b['group']=d['group']
    if d.get('disabled'):b['disabled']=True
    if d['type']=='box':b['size']=[2*v for v in d['args']]
    elif d['type']=='cylinder':b.update(height=2*d['args'][0],radius=d['args'][1])
    elif d['type']=='hull':b['vertices']=d['args'][0]
    elif d['type']=='mesh':b.update(triangles=d['args'][0],indices=d['args'][1])
    else:raise ValueError(d['type'])
    layout['blocks'].append(b)
partition(ROOT,layout,'EnginePit')
(OUT/'Boulders.json').write_text(json.dumps(M['scatterBoulders']),encoding='utf-8')
(OUT/'Materials.json').write_text(json.dumps(M['materials'],ensure_ascii=False),encoding='utf-8')
# Share the authored atmosphere component settings, while model/node IDs remain
# specific to the independent EnginePit scene.
scene=E.Element('scene',id='1');E.SubElement(scene,'component',type='Octree',id='1')
crater=E.parse(ROOT/'assets/Scenes/Crater.xml').getroot()
environment=copy.deepcopy(next(node for node in crater.findall('node') if any(a.get('name')=='Name' and a.get('value')=='Environment' for a in node.findall('attribute'))))
for c in environment.iter('component'):c.attrib.pop('id',None)
environment.set('id','2');scene.append(environment)
nid,cid=2,1
def node(parent,name):
    global nid
    nid+=1;r=E.SubElement(parent,'node',id=str(nid));attr(r,'Name',name);return r
def transform(r,d):
    p,q=d['p'],d['q'];attr(r,'Position',f'{-p[0]} {p[1]} {p[2]}');attr(r,'Rotation',f'{q[3]} {q[0]} {-q[1]} {-q[2]}');attr(r,'Scale',' '.join(map(str,d['s'])))
def build(parent,d):
    global cid
    r=node(parent,d['name'] or 'Mesh');transform(r,d)
    for mesh in d['meshes']:
        cid+=1;c=E.SubElement(r,'component',type='StaticModelGroup' if mesh.get('instances') else 'StaticModel',id=str(cid))
        attr(c,'Model','Model;'+mesh['model']);attr(c,'Material','Material;EnginePit/material-'+str(mesh['material'])+'.xml');attr(c,'Cast Shadows',str(mesh['shadow']).lower());attr(c,'Shadow Distance',90)
        if mesh.get('instances'):
            ids=[]
            for item in mesh['instances']:
                child=node(r,'Instance');transform(child,item);ids.append(child.get('id'))
            a=E.SubElement(c,'attribute',name='Instance Nodes');E.SubElement(a,'variant',type='Int',value=str(len(ids)))
            for value in ids:E.SubElement(a,'variant',type='Int',value=value)
    for child in d['children']:build(r,child)
for root in M['roots']:build(scene,json.loads((SOURCE/Path(root['file']).name).read_text('utf-8')))
sky=node(scene,'CraterSky');c=E.SubElement(sky,'component',type='Skybox');attr(c,'Model','Model;Models/Box.mdl');attr(c,'Material','Material;Crater/sky.xml')
camera=node(scene,'Camera');attr(camera,'Position','0 100 -400');E.SubElement(camera,'component',type='Camera')
xml(ROOT/'assets/Scenes/EnginePit.xml',scene)
paths={'Scenes/EnginePit.xml','EnginePit/Layout.json','EnginePit/Boulders.json','EnginePit/Materials.json','Models/Box.mdl'}
paths.update(p.relative_to(ROOT/'assets').as_posix() for p in OUT.rglob('*') if p.suffix in ('.json','.bin','.xml','.png'))
paths.discard('EnginePit/Resources.json')
paths.update(p.relative_to(ROOT/'assets').as_posix() for p in SH.iterdir())
paths.update({'Crater/Sky.hdr','Crater/sky.xml','Crater/Tonemap.cube','Crater/albedo.xml','Crater/nra.xml','Crater/dfg.png'})
paths.update('Crater/'+key+'-'+str(i)+'.bin' for key in ('albedo','nra') for i in range(6))
paths.update(p.relative_to(ROOT/'assets').as_posix() for p in shared.iterdir() if p.suffix in ('.shader','.shaderinc'))
paths.update(p.relative_to(ROOT/'assets').as_posix() for p in (shared.parent/'CraterPost').iterdir() if p.suffix=='.shader')
(OUT/'Resources.json').write_text(json.dumps(sorted(paths),ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'models':M['geometryCount'],'materials':len(M['materials']),'colliders':len(layout['blocks']),'nodes':nid,'heightRange':[lo,lo+span],'sharedShaderHooksEqual':True}))
