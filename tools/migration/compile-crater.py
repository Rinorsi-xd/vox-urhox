"""Translate source shader hooks and author an editor-visible UrhoX scene.
Input is the explicit browser export; the H5 checkout remains read-only.
"""
import json,re,struct,math,sys,copy,xml.etree.ElementTree as E
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/Crater';SH=ROOT/'assets/Shaders/BLGL/Crater';SH.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'tools/migration/crater-source'
CONTENT_ONLY='--content-only' in sys.argv
preserved_environment=None
if CONTENT_ONLY:
 existing_scene=E.parse(ROOT/'assets/Scenes/Crater.xml').getroot()
 preserved_environment=copy.deepcopy(next(n for n in existing_scene.findall('node') if any(a.get('name')=='Name' and a.get('value')=='Environment' for a in n.findall('attribute'))))
S=json.loads((SOURCE/'ShaderSources.json').read_text('utf8'));M=json.loads((SOURCE/'Manifest.json').read_text('utf8'))
def write(name,s):
 if not CONTENT_ONLY or not (SH/name).exists():(SH/name).write_text(s,encoding='utf8')
def clean(s):
 s=re.sub(r'#include <common>','',s);s=s.replace('uniform highp ','uniform ').replace('texture2D(','texture(').replace('texture2D( ','texture( ')
 return s.replace('cameraPosition','sourceCamera').replace('saturate( ','clamp01( ')
fog=S['fog'];fog=fog[fog.index('vec3 fRay'):fog.rindex('\n\t}\n\t#endif')]
fog=fog.replace('- fogDensity','0.00125').replace('fogColor','vec3(0.4969,0.3968,0.2747)')
fog=fog.replace('gl_FragColor.rgb = mix( gl_FragColor.rgb, fCol, fogFactor );','vec3 fogRGB = fCol * fogFactor;')
fog=fog.replace('gl_FragColor.rgb = mix( gl_FragColor.rgb, mix( fCol,','fogRGB = mix( fogRGB, mix( fCol,')
write('Fog.shaderinc','vec4 craterFog(vec3 vFogWorld, vec3 sourceCamera) {\n'+clean(fog)+'\nfloat a = fogFactor + poolF*(1.0-fogFactor);return vec4(fogRGB/max(a,0.00001),a);\n}\n')
common='float clamp01(float v){return clamp(v,0.0,1.0);}\n#include "Fog.shaderinc"\n'
grade=[(.95,[1.1,1.02,.9]),(.9,[1,1,1]),(.6,[1.14,1.06,.97]),(.9,[1.12,1.02,.9]),(.85,[1.06,.98,.9]),(.7,[.98,.9,.82])]
def selectfn(name,typ,values):return typ+' '+name+'(int i){'+''.join('if(i=='+str(i)+')return '+v+';' for i,v in enumerate(values))+'return '+values[-1]+';}\n'
for key in ['near','far']:
 parts=S[key];decl=clean(parts[0]);decl=re.sub(r'varying [^;]+;','',decl)
 decl=re.sub(r'uniform (?:float|vec3) (?:uInvSize|uSat|uTint)\[ 6 \];','',decl)
 decl=decl.replace('uniform float uMode;','const float uMode=0.0;').replace('uniform float uGroundHalf;','uniform float uGroundHalf=320.0;').replace('uniform vec2 uBakeFade;','uniform vec2 uBakeFade=vec2(52.0,66.0);')
 decl=decl.replace('uSat[ i ]','layerSat(i)').replace('uTint[ i ]','layerTint(i)')
 decl=decl.replace('float tLowQ = 0.0;','').replace('void tSample( float L,','void tSample( float tLowQ, float L,')
 constants=selectfn('layerSat','float',[str(v[0]) for v in grade])+selectfn('layerTint','vec3',['vec3('+','.join(map(str,v[1]))+')' for v in grade])
 body=clean(parts[1]);body=body.replace('diffuseColor.rgb *= tCol;','')
 body=body.replace('tLowQ = step','float tLowQ = step').replace('tSample( ','tSample( tLowQ, ')
 for i,v in enumerate(M['layers']):body=body.replace('uInvSize[ '+str(i)+' ]',str(v))
 prefix='shader_type spatial;\nrender_mode shading_model_pbr, cull_back;\n#define TERRAIN_FAR '+('1' if key=='far' else '0')+'\n'+('#define TERRAIN_GROUND\n' if key=='near' else '')
 tail='ALBEDO=tCol;ROUGHNESS=craterRoughness(clamp(tRough,0.35,1.0),(VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);NORMAL=normalize(tWN*vec3(-1.0,1.0,1.0));AO=mix(1.0,tAO,0.85);\n'
 if key=='near':tail+='vec2 gu=(vTWPos.xz+uGroundHalf)/(2.0*uGroundHalf);vec2 gb=texture(tGround,gu).rg;gb=mix(vec2(1.0),gb,step(abs(vTWPos.x),uGroundHalf-0.5)*step(abs(vTWPos.z),uGroundHalf-0.5));AO*=mix(1.0,gb.r,0.9);BACKLIGHT=vec3(mix(1.0,gb.g,smoothstep(uBakeFade.x,uBakeFade.y,tCam))*mix(1.0,gb.r,0.4));\n'
 else:tail+='BACKLIGHT=vec3(vSun);\n'
 tail+='\n'
 write(('Terrain' if key=='near' else 'Far')+'.shader',prefix+common+'#include "DirectLight.shaderinc"\n'+constants+decl+'\nvoid fragment(){\nvec3 vTWPos=VERTEX*vec3(-1.0,1.0,1.0);vec3 sourceCamera=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);vec3 vTWNrm=NORMAL*vec3(-1.0,1.0,1.0);vec4 vW=COLOR;vec3 vLegacy=vec3(0.4);float vSun=UV2.x;\n'+body+tail+'FOG=craterFog(vTWPos,sourceCamera);\n}\n')
decl=clean(S['map'][0]);decl=re.sub(r'varying [^;]+;','',decl)
# Runtime's shader lowering resolves uniform names inside helper scopes too.
# Keep the helper argument distinct from the material tint uniform.
decl=decl.replace('vec3 tint )','vec3 gradeTint )').replace('* tint;','* gradeTint;')
decl=decl.replace('uniform sampler2D tBake;','uniform sampler2D tBake : filter_linear, repeat_disable;')
decl=decl.replace('uniform float uTime;','uniform float uTime=0.0;').replace('uniform vec2 uBakeFade;','uniform vec2 uBakeFade=vec2(52.0,66.0);')
decl=decl.replace('uniform vec4 uHeightBox;','uniform vec4 uHeightBox=vec4(-320.0,-320.0,640.0,640.0);').replace('uniform float uSandK;','uniform float uSandK='+str(M['layers'][0])+';').replace('uniform float uCliffK;','uniform float uCliffK='+str(M['layers'][5])+';')
body=clean(S['map'][1]).replace('vec3 mCol = diffuseColor.rgb;','vec3 mCol = tint.rgb;').replace('diffuseColor.rgb = mCol;','')
body=body.replace('float tint = mTint','float brickTint = mTint').replace('uColor2, tint','uColor2, brickTint')
body=body.replace('float gh = texture( tHeight, hu ).r;','vec2 packedH=texture(tHeight,hu).rg;float gh=(packedH.r*65280.0+packedH.g*255.0)/65535.0*256.0-64.0;')
write('Map.shaderinc',common+'#include "DirectLight.shaderinc"\n'+decl+'''
uniform vec4 tint=vec4(1.0);uniform float roughness=0.6;uniform float metalness=0.0;uniform vec3 emission=vec3(0.0);
varying vec3 sourceObject;
void vertex(){sourceObject=VERTEX*vec3(-1.0,1.0,1.0);}
void fragment(){
vec3 sourceCamera=CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0);
vec3 vMWorld=VERTEX*vec3(-1.0,1.0,1.0);vec3 vMWN=NORMAL*vec3(-1.0,1.0,1.0);vec3 vMObj=sourceObject;
vec2 vMUv=UV;vec2 vMUv1=UV2;vec2 vMBake=COLOR.rg;
'''+body+'''
vec3 craterNormal=mWN;
#ifdef MAP_ROCK
craterNormal=mNrmW;
#endif
#ifdef MAP_PANEL
vec2 dH=vec2(dFdx(mHeight),dFdy(mHeight))*uWear.y*0.06*(1.0-smoothstep(25.0,80.0,mCamD));
craterNormal=mPerturb(vMWorld,craterNormal,dH,FRONT_FACING?1.0:-1.0);
#endif
vec2 bake=vec2(1.0);
#ifdef MAP_BAKE
bake=texture(tBake,vMUv1).rg;
#endif
#ifdef MAP_VBAKE
bake=vMBake;
#endif
ALBEDO=mCol;BACKLIGHT=vec3(mix(1.0,bake.g,smoothstep(uBakeFade.x,uBakeFade.y,mCamD))*mix(1.0,bake.r,0.3));
AO=mix(1.0,bake.r,0.9);ROUGHNESS=craterRoughness(clamp(roughness*mRoughK,0.04,1.0),(VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);METALLIC=metalness*mMetalK;
NORMAL=normalize(craterNormal*vec3(-1.0,1.0,1.0));
EMISSION=emission;FOG=craterFog(vMWorld,sourceCamera);
}
''')
sky=S['sky'];sky=re.sub(r'uniform vec3 uSun; uniform float uTime; varying vec3 vDir;','uniform vec3 uSun=vec3(-0.5209,0.5009,-0.6912);uniform float uTime=0.0;varying vec3 vDir;',sky)
sky=sky.replace('void main()', 'void fragment()').replace('gl_FragColor = vec4( c, 0.0 );','ALBEDO=c;')
write('Sky.shader','shader_type spatial;\nrender_mode unshaded,cull_front,depth_draw_never,fog_disabled;\n'+sky+'\nvoid vertex(){vDir=VERTEX*vec3(-1.0,1.0,1.0);}\n')
skyCapture=sky.replace('varying vec3 vDir;','').replace('void fragment()','void sky()').replace('normalize( vDir )','normalize(EYEDIR*vec3(-1.0,1.0,1.0))').replace('ALBEDO=c;','COLOR=c;ALPHA=0.0;')
write('SkyCapture.shader','shader_type sky;\n'+skyCapture)
write('Glow.shader','shader_type spatial;\nrender_mode unshaded,cull_disabled;\n'+common+'uniform vec4 tint=vec4(1.0);void fragment(){ALBEDO=tint.rgb;FOG=craterFog(VERTEX*vec3(-1.0,1.0,1.0),CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0));}\n')
write('Fx.shader',(SH/'Glow.shader').read_text().replace('unshaded,cull_disabled','unshaded,cull_disabled,blend_add,depth_draw_never').replace('ALBEDO=tint.rgb;','ALBEDO=tint.rgb;ALPHA=tint.a;'))
write('Scatter.shader','shader_type spatial;\nrender_mode shading_model_pbr,cull_disabled;\n'+common+'''#include "ScatterNormal.shaderinc"
uniform sampler2D albedo_map;uniform vec4 tint=vec4(1.0);uniform float roughness=1.0;uniform float alpha_cut=0.0;
void fragment(){vec4 a=texture(albedo_map,UV);ALBEDO=a.rgb*tint.rgb;ALPHA=a.a;ALPHA_SCISSOR_THRESHOLD=alpha_cut;ROUGHNESS=roughness;
NORMAL=craterScatterNormal(VERTEX,NORMAL,UV,FRONT_FACING?1.0:-1.0);
FOG=craterFog(VERTEX*vec3(-1.0,1.0,1.0),CAMERA_POSITION_WORLD*vec3(-1.0,1.0,1.0));}
''')
def xml(path,root):E.indent(root);E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
def param(root,name,v):
 if isinstance(v,list): E.SubElement(root,'parameter',name=name,value=' '.join(map(str,v)))
 else:E.SubElement(root,'parameter',name=name,type='Float',value=str(v))
def tex(root,name,path,typ='Texture2D'):E.SubElement(root,'surfacetexture',name=name,texture=path,type=typ)
# Identify exclusive animated housing materials from authored ownership, not
# transient export IDs. Shared/static materials keep their terrain-seam bias.
material_roles={}
def collect_material_roles(node,role='static'):
 role=node.get('dyn') or role
 for mesh in node['meshes']:material_roles.setdefault(mesh['material'],set()).add(role)
 for child in node['children']:collect_material_roles(child,role)
for root in M['roots']:collect_material_roles(json.loads((SOURCE/Path(root['file']).name).read_text('utf8')))
for key in ['albedo','nra']:
 r=E.Element('texture');
 for i in range(6):E.SubElement(r,'layer',name='Crater/'+key+'-'+str(i)+'.bin')
 E.SubElement(r,'address',coord='u',mode='wrap');E.SubElement(r,'address',coord='v',mode='wrap');E.SubElement(r,'filter',mode='anisotropic');xml(OUT/(key+'.xml'),r)
for i,d in enumerate(M['materials'],1):
 r=E.Element('material');kind=d['kind'];shader={'terrain':'Terrain','far':'Far','glow':'Glow','fx':'Fx','shield':'Fx','scatter':'Scatter'}.get(kind)
 if not shader:
  defines=d['defines'];shader='Map-'+ '-'.join(sorted(defines)) if defines else 'Map-plain'
  write(shader+'.shader','shader_type spatial;\nrender_mode shading_model_pbr,cull_disabled;\n'+''.join('#define '+k+'\n' for k in defines)+'#include "Map.shaderinc"\n')
 E.SubElement(r,'surfaceshader',name='Shaders/BLGL/Crater/'+shader+'.shader')
 param(r,'tint',d['color']+[d['opacity']]);param(r,'roughness',d['rough']);param(r,'metalness',d['metal']);param(r,'alpha_cut',d['alphaTest']);param(r,'emission',[v*d['emissionStrength'] for v in d['emission']])
 for k,v in d['uniforms'].items():param(r,k,v)
 for k,v in d['textures'].items():
  if k=='tBake':
   v=str(Path(v).with_suffix('.png')).replace('\\','/')
   assert (ROOT/'assets'/v).exists(), 'Restore Web-compatible PNG bakes before compiling'
  tex(r,{'map':'albedo_map','normal':'normal_map'}.get(k,k),v)
 if kind=='scatter':
  assert 'normal' in d['textures'], 'Scatter source requires its original normal texture'
  param(r,'normal_scale',d['normalScale'])
 if kind in ['terrain','far']:
  tex(r,'tAlb','Crater/albedo.xml','Texture2DArray');tex(r,'tNra','Crater/nra.xml','Texture2DArray');tex(r,'tGround',M['ground'].replace('.png','.bin'))
 elif kind not in ['scatter','glow','fx','shield']:
  tex(r,'tTerrA','Crater/albedo.xml','Texture2DArray');tex(r,'tTerrN','Crater/nra.xml','Texture2DArray');tex(r,'tHeight','Crater/height.png')
 if kind not in ['scatter','glow','fx','shield']:tex(r,'craterDFG','Crater/dfg.png')
 # Preserve authored surface positions; normal inflation exposed buried strips.
 # Preserve source offsets for terrain seams, decals and light strips.
 if kind not in ['terrain','far','scatter']:
  factor,units=(-2,-4) if kind in ['glow','fx','shield'] else ((-4,-16) if kind!='glass' and 'MAP_NOSAND' in d['defines'] else (-1,-2))
  # A rotating searchlight can become edge-on. DX11's unbounded slope offset
  # then pulls its housing through the ship walls (CRATER_SURFACE_DEPTH.md).
  if factor==-1 and material_roles.get(i)=={'searchlight'}:factor=0
  E.SubElement(r,'depthbias',constant=str(units/(2**24)),slopescaled=str(factor))
 E.SubElement(r,'renderorder',value='132' if kind=='fx' else '128');xml(OUT/f'material-{i}.xml',r)
r=E.Element('material');E.SubElement(r,'surfaceshader',name='Shaders/BLGL/Crater/SkyCapture.shader');E.SubElement(r,'renderorder',value='0');xml(OUT/'sky.xml',r)
# Pack the source 2 m collision heightfield as 16-bit RG shader data.
h=M['layout']['terrain'];N=h['n']+1;im=Image.new('RGB',(N,N));pix=im.load()
if isinstance(h['heights'],dict):h['heights']=[h['heights'][str(i)] for i in range(N*N)]
from crater_layout import build as build_layout_parts
build_layout_parts(ROOT,M['layout'])
runtime_materials=json.loads(json.dumps(M['materials']))
for material in runtime_materials:
 if 'tBake' in material['textures']:
  material['textures']['tBake']=str(Path(material['textures']['tBake']).with_suffix('.png')).replace('\\','/')
(OUT/'Materials.json').write_text(json.dumps(runtime_materials,ensure_ascii=False),encoding='utf8')
(OUT/'Boulders.json').write_text(json.dumps(M['scatterBoulders']),encoding='utf8')
for x in range(N):
 for z in range(N):v=round((h['heights'][x*N+z]+64)/256*65535);pix[x,z]=(v//256,v%256,0)
im.save(OUT/'height.png')
# Every imported node remains authored and inspectable in the editor.
scene=E.Element('scene',id='1');nid=1;cid=0
def attr(r,n,v):E.SubElement(r,'attribute',name=n,value=str(v))
def comp(r,typ):
 global cid;cid+=1;return E.SubElement(r,'component',type=typ,id=str(cid))
def node(r,name):
 global nid;nid+=1;n=E.SubElement(r,'node',id=str(nid));attr(n,'Name',name);return n
comp(scene,'Octree');env=node(scene,'Environment');zone=comp(env,'Zone')
for k,v in {'Bounding Box Min':'-3000 -300 -3000','Bounding Box Max':'3000 1500 3000','Ambient Color':'0.17 0.2 0.25 1','Fog Color':'0.4969 0.3968 0.2747 1','Depth Fog Start':'400','Depth Fog End':'2400','Depth Fog AutoCompute':'false','Environment Source Texture':'Texture2D;Crater/Sky.hdr','Env texture diff intensity':'.75','Env texture spec intensity':'.75','Bloom Enable':'true','Tonemap Mode':'LUT','Tonemap LUT':'ColorLUT;Crater/Tonemap.cube','Auto Exposure Enable':'true','Auto Exposure Plus Enable':'true','Auto Exposure Min Brightness':'1','Auto Exposure Max Brightness':'1','Auto Exposure Bias':'0','Auto Exposure Extended Luminance Range':'false','Auto Exposure Force Target':'true'}.items():attr(zone,k,v)
sunNode=node(env,'CraterSun');sun=comp(sunNode,'Light');attr(sun,'Light Type','Directional');attr(sun,'Color','1 0.8714 0.6867 1');attr(sun,'Brightness Multiplier','3.3');attr(sun,'Use Temperature','false');attr(sun,'Cast Shadows','true');attr(sun,'CSM Splits','15 40 75 0');attr(sun,'Auto Shadow Cascade','false');attr(sun,'Shadow Intensity','0.05');attr(sun,'Shadow Resolution','1')
for k,v in {'Bloom Mode':'UE','Bloom UE Intensity':'.18','Bloom UE Threshold':'1.3','Using Vignette':'true','Vignette Intensity':'.3'}.items():attr(zone,k,v)
attr(sunNode,'Rotation','0.919566 0.272358 -0.283232 0')
def transform(n,d):
 p=d['p'];q=d['q'];attr(n,'Position',f'{-p[0]} {p[1]} {p[2]}');attr(n,'Rotation',f'{q[3]} {q[0]} {-q[1]} {-q[2]}');attr(n,'Scale',' '.join(map(str,d['s'])))
dyn=[]
def build(parent,d):
 n=node(parent,d['name'] or 'Mesh');transform(n,d)
 if d.get('dyn'):dyn.append({'id':nid,'kind':d['dyn'],'name':d['name']})
 for mesh in d['meshes']:
  model_path=mesh['model'].removesuffix('.mdl')+'.bin' if mesh['model'].endswith('.mdl') else mesh['model']
  sm=comp(n,'StaticModelGroup' if mesh.get('instances') else 'StaticModel');attr(sm,'Model','Model;'+model_path);attr(sm,'Material','Material;Crater/material-'+str(mesh['material'])+'.xml');attr(sm,'Cast Shadows',str(mesh['shadow']).lower());attr(sm,'Shadow Distance',90)
  if mesh.get('instances'):
   # Serialize engine's actual node-ID vector so instances also appear in editor.
   instanceIds=[]
   for inst in mesh['instances']:
    child=node(n,'Instance');transform(child,inst);instanceIds.append(child.get('id'))
   ids=E.SubElement(sm,'attribute',name='Instance Nodes');E.SubElement(ids,'variant',type='Int',value=str(len(instanceIds)))
   for value in instanceIds:E.SubElement(ids,'variant',type='Int',value=value)
 for c in d['children']:build(n,c)
if preserved_environment is not None:
 scene.remove(env);scene.insert(1,preserved_environment)
for root in M['roots']:build(scene,json.loads((SOURCE/Path(root['file']).name).read_text('utf8')))
sk=node(scene,'CraterSky');sm=comp(sk,'Skybox');attr(sm,'Model','Model;Models/Box.mdl');attr(sm,'Material','Material;Crater/sky.xml');attr(sm,'Cast Shadows','false')
camera=node(scene,'Camera');attr(camera,'Position','-350 220 -380');comp(camera,'Camera')
xml(ROOT/'assets/Scenes/Crater.xml',scene);(OUT/'Dynamics.json').write_text(json.dumps(dyn),encoding='utf8')
print(json.dumps({'models':M['geometryCount'],'materials':len(M['materials']),'nodes':nid,'components':cid,'dynamicNodes':len(dyn),'teleports':len(M['layout']['teleports'])}))

# Explicit media dependencies for cancellable map-entry readiness. Download only;
# model/material creation remains in the engine async scene loader.
from crater_height import build as build_visual_height
build_visual_height(ROOT)
paths={'Scenes/Crater.xml','Crater/Layout.json','Crater/Dynamics.json','Crater/Materials.json','Crater/Boulders.json','Crater/Sky.hdr','Crater/sky.xml','Models/Box.mdl'}
paths.update('Crater/'+p.name for p in OUT.iterdir() if p.suffix in ('.png','.xml','.cube','.bin') and not (p.suffix=='.xml' and p.with_suffix('.png').exists()))
# Arrays read the .bin PNG payloads; their exported PNG originals are offline inputs.
paths.difference_update('Crater/'+kind+'-'+str(i)+'.png' for kind in ('albedo','nra') for i in range(6))
paths.update(p.relative_to(ROOT/'assets').as_posix() for p in (OUT/'Layout').glob('*.json'))
paths.update('Shaders/BLGL/Crater/'+p.name for p in SH.iterdir() if p.suffix in ('.shader','.shaderinc'))
paths.update('Shaders/BLGL/CraterPost/'+p.name for p in (SH.parent/'CraterPost').iterdir() if p.suffix=='.shader')
(OUT/'Resources.json').write_text(json.dumps(sorted(paths),ensure_ascii=False,indent=2),encoding='utf8')
