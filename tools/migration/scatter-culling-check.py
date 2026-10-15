import hashlib,json,math
from pathlib import Path
import xml.etree.ElementTree as ET
import sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'.tmp/nav-python-deps'))
from lupa.lua54 import LuaRuntime

def attrs(node):
    return {a.attrib['name']:a.attrib.get('value','') for a in node.findall('attribute')}

def multiply(a,b):
    return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]

def transform(node):
    a=attrs(node)
    p=list(map(float,a.get('Position','0 0 0').split()))
    w,x,y,z=map(float,a.get('Rotation','1 0 0 0').split())
    sx,sy,sz=map(float,a.get('Scale','1 1 1').split())
    return [[(1-2*y*y-2*z*z)*sx,(2*x*y-2*w*z)*sy,(2*x*z+2*w*y)*sz,p[0]],
            [(2*x*y+2*w*z)*sx,(1-2*x*x-2*z*z)*sy,(2*y*z-2*w*x)*sz,p[1]],
            [(2*x*z-2*w*y)*sx,(2*y*z+2*w*x)*sy,(1-2*x*x-2*y*y)*sz,p[2]],
            [0,0,0,1]]

nodes={};fixtures=[]
def walk(node,parent):
    world=multiply(parent,transform(node))
    key=int(node.attrib.get('id','0'))
    nodes[key]={'id':key,'matrix':{'m'+str(r)+str(c):world[r][c] for r in range(3) for c in range(4)}}
    for component in node.findall('component'):
        if component.attrib.get('type')=='StaticModelGroup' and attrs(component).get('Model')=='Model;Crater/mesh-293.bin':
            ids=[int(v.attrib['value']) for v in component.findall("attribute[@name='Instance Nodes']/variant")]
            assert ids[0]==len(ids)-1
            fixtures.append((key,ids[1:]))
    for child in node.findall('node'):walk(child,world)

scene=ET.parse(root/'assets/Scenes/Crater.xml').getroot()
walk(scene,[[int(r==c) for c in range(4)] for r in range(4)])
fixture=[dict(nodes[key],instances=[nodes[i] for i in ids]) for key,ids in fixtures]
lua=LuaRuntime(unpack_returned_tuples=True)
def table(value):
    if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([table(v) for v in value])
    return value
core=root/'tools/migration/scatter-culling-core.lua'
lua.globals().SCATTER_CORE=lua.execute(core.read_text(encoding='utf-8'))
lua.globals().SCATTER_FIXTURE=table(fixture)
result=lua.execute((root/'tools/migration/scatter-culling-check.lua').read_text(encoding='utf-8'))
report={k:v for k,v in result.items()}
report.update(result='PASSED',coreSha256=hashlib.sha256(core.read_bytes()).hexdigest(),sceneSha256=hashlib.sha256((root/'assets/Scenes/Crater.xml').read_bytes()).hexdigest(),scope='Actual authored XML positions/affine transforms and QA partition core using native-object stubs. Not renderer, GPU, draw-distance semantics, or performance acceptance.')
(root/'docs/migration/evidence/scatter-culling-offline.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
