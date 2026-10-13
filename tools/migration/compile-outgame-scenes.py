"""Build editor-visible scenes and SurfaceShaders from frozen scene exports."""
from pathlib import Path
import json, re, os, xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[2]
BASE=json.loads((ROOT/'docs/migration/outgame-baseline.json').read_text('utf8'))
SOURCE=Path(BASE['snapshot'])
SH=ROOT/'assets/Shaders/BLGL/Outgame'
SH.mkdir(parents=True,exist_ok=True)
ground=(SOURCE/'three/src/review/salvageTerrain/groundMaterial.js').read_text('utf8')
ground=re.search(r'const GLSL = /\* glsl \*/`(.*?)`;',ground,re.S)[1]
# Static source terrain is evaluated by bake-salvage-ground.cjs, outside runtime.
# This avoids multi-minute PBR shader optimization on DX11 and ANGLE.
(SH/'Ground.shader').write_text('''shader_type spatial;
render_mode shading_model_pbr,cull_back;
uniform sampler2D groundBaked : filter_linear_mipmap, repeat_disable;
void fragment(){
    vec2 uv=(VERTEX.xz+vec2(1024.0))/2048.0;
    vec4 gc=texture(groundBaked,uv);
    ALBEDO=pow(gc.rgb,vec3(2.2));ROUGHNESS=gc.a;
}
''',encoding='utf8')
common='uniform vec4 tint=vec4(1.0);uniform vec3 glow=vec3(0.0);uniform float roughness=0.8;uniform float metallic=0.0;\n'
for name,mode in [('Solid','shading_model_pbr,cull_back'),('Double','shading_model_pbr,cull_disabled'),('Unlit','unshaded,cull_disabled'),('Alpha','shading_model_pbr,cull_disabled,blend_mix,depth_draw_never')]:
    alpha='ALPHA=tint.a;' if name=='Alpha' else ''
    (SH/(name+'.shader')).write_text('shader_type spatial;\nrender_mode '+mode+';\n'+common+'void fragment(){ALBEDO=tint.rgb*COLOR.rgb;EMISSION=glow;ROUGHNESS=roughness;METALLIC=metallic;'+alpha+'}\n',encoding='utf8')
(SH/'Texture.shader').write_text('shader_type spatial;\nrender_mode unshaded,cull_disabled,blend_mix,depth_draw_never;\nuniform sampler2D albedo;uniform vec4 tint=vec4(1.0);void fragment(){vec4 a=texture(albedo,UV);ALBEDO=a.rgb*tint.rgb;ALPHA=a.a*tint.a;}\n',encoding='utf8')
def attr(parent,name,value):
    E.SubElement(parent,'attribute',name=name,value=str(value))
def xml(file,element):
    E.indent(element);E.ElementTree(element).write(file,encoding='utf-8',xml_declaration=True)
for folder in ([os.environ['VOX_COMPILE_SCENE']] if os.environ.get('VOX_COMPILE_SCENE') else ('Warehouse','Salvage')):
    out=ROOT/'assets'/folder;data=json.loads((out/('RunManifest.json' if folder=='Salvage' else 'Manifest.json')).read_text('utf8'))
    refs=[]
    for i,m in enumerate(data['materials']):
        root=E.Element('material')
        shader='Ground' if m['ground'] else 'Texture' if m['map'] is not None else 'Alpha' if m['opacity']<1 else 'Unlit' if m.get('unlit',m.get('name')=='MeshBasicMaterial') else 'Double' if m['double'] else 'Solid'
        path='Shaders/BLGL/Outgame/'+shader+'.shader';refs.append(path)
        E.SubElement(root,'surfaceshader',name=path)
        for name,v in [('tint',m['color']+[m['opacity']]),('glow',m['emission']),('roughness',m['roughness']),('metallic',m['metallic'])]:
            E.SubElement(root,'parameter',name=name,**({'value':' '.join(map(str,v))} if isinstance(v,list) else {'type':'Float','value':str(v)}))
        for name,index in [('albedo',m['map']),('uMat',m['matTexture'])]:
            if index is not None:
                p=folder+'/texture-'+str(index)+'.png';E.SubElement(root,'surfacetexture',name=name,texture=p,type='Texture2D');refs.append(p)
        if m['ground']:
            p=folder+'/GroundBaked.png'
            assert (ROOT/'assets'/p).exists(), 'Run bake-salvage-ground.cjs first'
            E.SubElement(root,'surfacetexture',name='groundBaked',texture=p,type='Texture2D');refs.append(p)
        p=folder+'/material-'+str(i)+'.xml';xml(ROOT/'assets'/p,root);refs.append(p)
    scene=E.Element('scene');E.SubElement(scene,'component',type='Octree')
    environment=E.SubElement(scene,'node');attr(environment,'Name',folder+'Environment')
    zone=E.SubElement(environment,'component',type='Zone');attr(zone,'Bounding Box Min','-12000 -2000 -12000');attr(zone,'Bounding Box Max','12000 12000 12000')
    attr(zone,'Priority',10);attr(zone,'Ambient Color','0.14 0.16 0.20 1' if folder=='Warehouse' else '0.26 0.29 0.33 1')
    attr(zone,'Fog Color','0.004 0.005 0.007 1' if folder=='Warehouse' else '0.66 0.59 0.47 1')
    attr(zone,'Depth Fog Start',150 if folder=='Warehouse' else 1400);attr(zone,'Depth Fog End',240 if folder=='Warehouse' else 7600)
    attr(zone,'Environment Source Texture','Texture2D;Hangar/HangarEnv.hdr');refs.append('Hangar/HangarEnv.hdr')
    attr(zone,'Tonemap Mode','ACES');attr(zone,'Bloom Enable','true');attr(zone,'Bloom Mode','UE');attr(zone,'Bloom UE Intensity',0.18);attr(zone,'Bloom UE Threshold',1.3)
    for i,m in enumerate(data['models']):
        node=E.SubElement(environment,'node');attr(node,'Name',folder+'_Batch_'+str(i))
        comp=E.SubElement(node,'component',type='StaticModel');attr(comp,'Model','Model;'+m['model']);attr(comp,'Material','Material;'+folder+'/material-'+str(m['material'])+'.xml');attr(comp,'Cast Shadows',str(m['shadow']).lower())
        refs.append(m['model'])
    lights=data['lights'] if folder=='Warehouse' else [{'type':'DirectionalLight','color':[1,.77,.51],'intensity':2.3,'position':[0,0,0],'range':100}]
    for i,l in enumerate(lights):
        if i>10:break
        node=E.SubElement(environment,'node');attr(node,'Name',folder+'_Light_'+str(i));attr(node,'Position',' '.join(map(str,[-l['position'][0],l['position'][1],l['position'][2]])))
        if l['type']=='DirectionalLight':attr(node,'Rotation','0.880 0.365 -0.280 0.116')
        comp=E.SubElement(node,'component',type='Light');attr(comp,'Light Type','Directional' if l['type']=='DirectionalLight' else 'Point');attr(comp,'Color',' '.join(map(str,l['color']+[1])));attr(comp,'Brightness',min(3,l['intensity']));attr(comp,'Range',l['range']);attr(comp,'Cast Shadows','true' if i==0 else 'false')
    name='Scenes/'+folder+'.xml';xml(ROOT/'assets'/name,scene);refs.append(name)
    if folder=='Salvage' and (out/'Physics.json').exists():
        physics=json.loads((out/'Physics.json').read_text('utf8'))
        refs.extend(['Salvage/Height.bin','Salvage/Physics.json','Salvage/Gameplay.json','Salvage/RunData.json'])
        refs.extend(m['model'] for m in physics['terrain'])
        refs.extend(c['model'] for c in physics['colliders'] if c.get('model'))
        refs.extend(m['model'] for group in physics['lootModels'] for m in group)
        deps=json.loads((ROOT/'assets/Parts/Dependencies.json').read_text('utf8'))
        run=json.loads((out/'RunData.json').read_text('utf8'))
        for variants in run['enemies'].values():
            for enemy in variants:
                for part in enemy['source']['parts']:
                    key='thrusterUp2' if part[0]=='thruster' else part[0]
                    refs.extend(deps[key])
                    refs.extend(deps.get(key+'Side',[]))
        refs.append('Shaders/BLGL/Combat/Objective.shader')
    (out/'Resources.json').write_text(json.dumps(sorted(set(refs))),encoding='utf8')
    print(folder,len(data['models']),'batches',len(set(refs)),'resource references')
