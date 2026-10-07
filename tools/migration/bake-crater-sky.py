"""Deterministic HDR panorama of atmosphere.js::skyMaterial, linear RGB."""
from pathlib import Path
import numpy as np
out=Path(__file__).resolve().parents[2]/'assets/Crater/Sky.hdr'
w,h=1024,512
u,v=np.meshgrid((np.arange(w)+.5)/w,(np.arange(h)+.5)/h)
theta=u*2*np.pi;phi=v*np.pi
# Urho panorama longitude is engine space; source scene mirrors X.
d=np.stack((-np.sin(phi)*np.sin(theta),np.cos(phi),np.sin(phi)*np.cos(theta)),axis=-1)
def linear(hex):
 a=np.array([(hex>>16)&255,(hex>>8)&255,hex&255])/255
 return np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)
def mix(a,b,t):return a*(1-t[...,None])+b*t[...,None]
def smooth(a,b,x):t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def noise(p):
 i=np.floor(p);f=p-i;f=f*f*(3-2*f)
 def hsh(x):q=np.sin(x[...,0]*127.1+x[...,1]*311.7)*43758.5453;return q-np.floor(q)
 return (hsh(i)*(1-f[...,0])+hsh(i+[1,0])*f[...,0])*(1-f[...,1])+(hsh(i+[0,1])*(1-f[...,0])+hsh(i+[1,1])*f[...,0])*f[...,1]
zen,hor,sun,haze=map(linear,[0x6f8399,0xbba98f,0xfff0d8,0xf3c894]);y=d[...,1]
c=mix(hor,zen,np.clip(y*1.6,0,1)**.55);c=np.where((y>0)[...,None],c,hor*(1-np.minimum(-y*2,.25))[...,None])
s=np.maximum(0,d@ (np.array([-.52,.5,-.69])/np.linalg.norm([-.52,.5,-.69])))
c=mix(c,haze*1.2,s**5*.55*(1-np.minimum(np.maximum(y,0)*1.5,.8)))
c+=sun*(s**48*.9+s**600*6+smooth(.99955,.9998,s)*40)[...,None]
q=d[...,[0,2]]/np.maximum(y+.12,.01)[...,None]*1.6+np.array([.04,.02]);cl=noise(q)*.6+noise(q*2.7+3.1)*.4
cl=smooth(.55,.85,cl)*smooth(.02,.25,y)*.35
c=mix(c,mix(hor,sun,.35+.4*s**3)*1.15,cl)
peak=np.max(c,axis=-1);mant,exp=np.frexp(peak);scale=mant*256/np.maximum(peak,1e-30)
rgbe=np.concatenate((np.clip(c*scale[...,None],0,255).astype(np.uint8),(exp+128).astype(np.uint8)[...,None]),axis=-1)
out.write_bytes(b'#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n'+f'-Y {h} +X {w}\n'.encode()+rgbe.tobytes())
print(out)
