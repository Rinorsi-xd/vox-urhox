// Evaluate the frozen H5 ground shader offline; runtime keeps PBR lighting.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const deps='C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/';
const {chromium}=require(deps+'playwright'),sharp=require(deps+'sharp');
const root=path.resolve(__dirname,'../..'),baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/migration/outgame-baseline.json')));
const source=fs.readFileSync(path.join(baseline.snapshot,'three/src/review/salvageTerrain/groundMaterial.js'),'utf8');
const glsl=source.match(/const GLSL = \/\* glsl \*\/`([\s\S]*?)`;/)[1].replace(/varying vec3 \w+;/g,'');
const height=fs.readFileSync(path.join(root,'assets/Salvage/Height.bin'));
const size=2048;
(async()=>{const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{const page=await browser.newPage();const result=await page.evaluate(async({glsl,heights,mat,size})=>{
  const canvas=document.createElement('canvas');canvas.width=canvas.height=size;
  const g=canvas.getContext('webgl2',{premultipliedAlpha:false,preserveDrawingBuffer:true});if(!g)throw Error('WebGL2 bake unavailable');
  const compile=(kind,text)=>{const s=g.createShader(kind);g.shaderSource(s,text);g.compileShader(s);if(!g.getShaderParameter(s,g.COMPILE_STATUS))throw Error(g.getShaderInfoLog(s));return s;};
  const p=g.createProgram();g.attachShader(p,compile(g.VERTEX_SHADER,'#version 300 es\nvoid main(){vec2 xy=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(xy*2.0-1.0,0,1);}'));
  g.attachShader(p,compile(g.FRAGMENT_SHADER,'#version 300 es\nprecision highp float;precision highp int;\n'+glsl+`
uniform sampler2D heightMap;out vec4 outColor;
float heightAt(vec2 uv){return texture(heightMap,uv).r;}
void main(){vec2 uv=gl_FragCoord.xy/vec2(${size}.0);vec2 stepUV=vec2(4.0/2048.0,0.0);
float h=heightAt(uv);float dx=heightAt(uv+stepUV)-heightAt(uv-stepUV);float dz=heightAt(uv+stepUV.yx)-heightAt(uv-stepUV.yx);
vec3 n=normalize(vec3(-dx,8.0,-dz));vec3 w=vec3(uv.x*2048.0-1024.0,h,1024.0-uv.y*2048.0);
outColor=groundColor(w,n);}`));
  g.linkProgram(p);if(!g.getProgramParameter(p,g.LINK_STATUS))throw Error(g.getProgramInfoLog(p));g.useProgram(p);
  const texture=(unit,internal,w,h,format,type,data)=>{g.activeTexture(g.TEXTURE0+unit);const t=g.createTexture();g.bindTexture(g.TEXTURE_2D,t);g.texImage2D(g.TEXTURE_2D,0,internal,w,h,0,format,type,data);g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MIN_FILTER,g.NEAREST);g.texParameteri(g.TEXTURE_2D,g.TEXTURE_MAG_FILTER,g.NEAREST);g.texParameteri(g.TEXTURE_2D,g.TEXTURE_WRAP_S,g.CLAMP_TO_EDGE);g.texParameteri(g.TEXTURE_2D,g.TEXTURE_WRAP_T,g.CLAMP_TO_EDGE);};
  const image=new Image();image.src='data:image/png;base64,'+mat;await image.decode();const c=document.createElement('canvas');c.width=c.height=1025;const ctx=c.getContext('2d');ctx.drawImage(image,0,0);texture(0,g.RGBA,1025,1025,g.RGBA,g.UNSIGNED_BYTE,ctx.getImageData(0,0,1025,1025).data);
  // HeightField stores X-major rows; rotate into source map XY texture order.
  const bytes=Uint8Array.from(atob(heights),c=>c.charCodeAt(0));const raw=new Float32Array(bytes.buffer);const values=new Float32Array(raw.length);
  for(let x=0;x<513;x++)for(let z=0;z<513;z++)values[z*513+x]=raw[(512-x)*513+z];
  texture(1,g.R32F,513,513,g.RED,g.FLOAT,values);g.uniform1i(g.getUniformLocation(p,'heightMap'),1);g.uniform1i(g.getUniformLocation(p,'uMat'),0);
  for(const [name,value] of Object.entries({uHalf:1024,uCell:2,uRes:1025,uDetail:1}))g.uniform1f(g.getUniformLocation(p,name),value);
  g.viewport(0,0,size,size);g.drawArrays(g.TRIANGLES,0,3);g.finish();const pixels=new Uint8Array(size*size*4);g.readPixels(0,0,size,size,g.RGBA,g.UNSIGNED_BYTE,pixels);
  if(g.getError()!==g.NO_ERROR)throw Error('Bake readback failed');let sum=0;for(let i=0;i<pixels.length;i+=4096)sum+=pixels[i];if(!sum)throw Error('Blank ground bake');
  let encoded='';for(let i=0;i<pixels.length;i+=32768)encoded+=String.fromCharCode(...pixels.subarray(i,i+32768));return btoa(encoded);
 },{glsl,heights:height.subarray(20).toString('base64'),mat:fs.readFileSync(path.join(root,'assets/Salvage/texture-0.png')).toString('base64'),size});
 const pixels=Buffer.from(result,'base64');await sharp(pixels,{raw:{width:size,height:size,channels:4}}).png().toFile(path.join(root,'assets/Salvage/GroundBaked.png'));
 const report={sourceCommit:baseline.commit,sourceShaderSha256:crypto.createHash('sha256').update(source).digest('hex'),size,metresPerTexel:2048/size,bytes:pixels.length,method:'Frozen groundColor at source height and slope; RGB sRGB, alpha roughness; no baked light'};
 fs.writeFileSync(path.join(root,'docs/migration/evidence/salvage-ground-bake.json'),JSON.stringify(report,null,2));console.log(report);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
