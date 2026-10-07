"""Bake the H5 crater GradeShader + Three ACES into UrhoX's log-domain LUT."""
from pathlib import Path
import hashlib
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path('D:/Rino_Project/Vox')
SIZE=49
EXPOSURE=1.1
GREY=444/1023
ZERO=2**(-GREY*14)*.18

def grade_aces(rgb, exposure=EXPOSURE):
    rgb=np.maximum(rgb,0)
    lum=rgb@np.array([.2126,.7152,.0722])
    w=np.clip((lum-.02)/.58,0,1);w=w*w*(3-2*w)
    rgb=rgb*(np.array([.93,.98,1.05])*(1-w[...,None])+np.array([1.06,1,.91])*w[...,None])
    rgb=.18*(rgb/.18+1e-5)**1.08
    lum=rgb@np.array([.2126,.7152,.0722])
    rgb=np.maximum(lum[...,None]*(1-1.05)+rgb*1.05,0)*exposure/.6
    rgb=rgb@np.array([[.59719,.076,.02840],[.35458,.90834,.13383],[.04823,.01566,.83777]])
    rgb=(rgb*(rgb+.0245786)-.000090537)/(rgb*(.983729*rgb+.432951)+.238081)
    return np.clip(rgb@np.array([[1.60475,-.10208,-.00327],[-.53108,1.10813,-.07276],[-.07367,-.00605,1.07602]]),0,1)

def main():
    axis=np.maximum(2**((np.linspace(0,1,SIZE)-GREY)*14)*.18-ZERO,0)
    b,g,r=np.meshgrid(axis,axis,axis,indexing='ij')
    colors=grade_aces(np.stack((r,g,b),axis=-1)).reshape(-1,3)
    path=ROOT/'assets/Crater/Tonemap.cube'
    with path.open('w',encoding='ascii') as f:
        f.write(f'TITLE "H5 crater Grade + Three ACES exposure {EXPOSURE}"\nLUT_3D_SIZE {SIZE}\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n')
        np.savetxt(f,colors,fmt='%.7f')
    inputs=[[.02]*3,[.05]*3,[.18]*3,[.5]*3,[1]*3,[3]*3,[.05,.4,1],[1,.1,.02]]
    cases=[]
    for exposure in [.6,1,1.1,1.4]:
        linear=grade_aces(np.array(inputs),exposure)
        srgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
        cases.append({'exposure':exposure,'pixels':np.rint(srgb*255).astype(int).tolist()})
    sources=['three/src/render/pipeline.js','three/src/battle/craterWorld.js','three/vendor/three/build/three.module.js']
    evidence={'size':SIZE,'default_exposure':EXPOSURE,'inputs':inputs,'expected':cases,
        'source_hashes':{s:hashlib.sha256((SOURCE/s).read_bytes()).hexdigest() for s in sources}}
    (ROOT/'tools/migration/crater-color-reference.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'path':str(path),'size':SIZE,'bytes':path.stat().st_size}))

if __name__=='__main__':main()
