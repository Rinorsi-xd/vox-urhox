"""Independent CPU H5 pipeline oracle: bilinear texture fetches and FP16 targets."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from importlib.util import spec_from_file_location, module_from_spec

ROOT=Path(__file__).resolve().parents[2]
spec=spec_from_file_location('grade',ROOT/'tools/migration/bake-crater-tonemap.py')
grade=module_from_spec(spec);spec.loader.exec_module(grade)

def half(a): return a.astype(np.float16).astype(np.float64)
def uv(w,h):
    x,y=np.meshgrid((np.arange(w)+.5)/w,(np.arange(h)+.5)/h)
    return np.stack((x,y),axis=-1)
def sample(a,p):
    h,w=a.shape[:2];xy=p*np.array([w,h])-.5
    low=np.floor(xy).astype(int);f=xy-low
    x0=np.clip(low[...,0],0,w-1);x1=np.clip(low[...,0]+1,0,w-1)
    y0=np.clip(low[...,1],0,h-1);y1=np.clip(low[...,1]+1,0,h-1)
    fx=f[...,0,None];fy=f[...,1,None]
    return (a[y0,x0]*(1-fx)+a[y0,x1]*fx)*(1-fy)+(a[y1,x0]*(1-fx)+a[y1,x1]*fx)*fy
def smooth(t):
    t=np.clip(t,0,1);return t*t*(3-2*t)
def shrink(n): return max(1,int(n/2+.5))
def bloom(a,strength,radius,threshold):
    height,width=a.shape[:2];w,h=shrink(width),shrink(height)
    c=sample(a,uv(w,h));t=smooth((c@np.array([.2126,.7152,.0722])-threshold)/.01)
    c=half(c*t[...,None]);levels=[]
    for radius_px in [6,10,14,18,22]:
        sigma=radius_px/3
        coeff=np.array([.39894*np.exp(-.5*i*i/sigma**2)/sigma for i in range(radius_px)])
        for direction in [(1/w,0),(0,1/h)]:
            p=uv(w,h);out=sample(c,p)*coeff[0]
            for i in range(1,radius_px,2):
                a1,b1=coeff[i],coeff[i+1] if i+1<radius_px else 0
                weight=a1+b1;offset=(i*a1+(i+1)*b1)/weight*np.array(direction)
                out+=(sample(c,p+offset)+sample(c,p-offset))*weight
            c=half(out)
        levels.append(c);w,h=shrink(w),shrink(h)
    p=uv(shrink(width),shrink(height))
    return half(sum(sample(c,p)*(f*(1-radius)+(1.2-f)*radius) for c,f in zip(levels,[1,.8,.6,.4,.2]))*3*strength)
def render(w,h,exposure=1.1,bloom_strength=.18,mist=.04,vignette=.3):
    p=uv(w,h);x,y=p[...,0],p[...,1]
    c=np.stack((.02+.25*x,.04+.4*y,np.full_like(x,.12)),axis=-1)
    c[np.linalg.norm(p-[.35,.4],axis=-1)<.065]=[.3,4,8]
    c[(x>.61)&(x<.64)&(y>.2)&(y<.78)]=[5,2,.03]
    c=half(c);c=half(c*np.minimum(1,4/np.maximum(c.max(axis=-1),.0001))[...,None])
    c=half(c+sample(bloom(c,bloom_strength,.6,1.3),p))
    c=c+sample(bloom(c,mist,1,0),p)
    c=grade.grade_aces(c,exposure)
    c=half(np.where(c<=.0031308,12.92*c,1.055*c**(1/2.4)-.055))
    d=p-.5;offset=d*(d*d).sum(axis=-1)[...,None]*.0006*4
    c=np.stack((sample(c,p-offset)[...,0],sample(c,p)[...,1],sample(c,p+offset)[...,2]),axis=-1)
    v=smooth((np.linalg.norm(d*[1,h/w],axis=-1)*1.25-.85)/(.2-.85))
    c*=((1-vignette)*(1-v)+v)[...,None]
    return np.rint(np.clip(c,0,1)*255).astype(np.uint8)
def main():
    cases=[]
    for name,w,h,params in [('default',256,192,{}),('exposure',256,192,{'exposure':.6}),
                            ('no-mist',256,192,{'mist':0}),('no-bloom',256,192,{'bloom_strength':0}),
                            ('odd-resize',129,97,{})]:
        out=render(w,h,**params);points=[]
        for y in range(7,h-7,13):
            for x in range(7,w-7,13): points.append({'x':x,'y':y,'rgb':out[y,x].tolist()})
        Image.fromarray(out).save(ROOT/f'.tmp/post-reference-{name}.png')
        cases.append({'name':name,'width':w,'height':h,'points':points})
    (ROOT/'tools/migration/crater-post-reference.json').write_text(json.dumps(cases,indent=2)+'\n',encoding='utf8')
    print('Generated five CPU pipeline reference frames')
if __name__=='__main__':main()
