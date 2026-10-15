// Rasterize the frozen CSS radial-gradient tile, including its source alpha.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
function crc(bytes){let c=0xffffffff;for(const b of bytes){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return (c^0xffffffff)>>>0;}
function chunk(type,data){const tag=Buffer.from(type),size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(data.length);sum.writeUInt32BE(crc(Buffer.concat([tag,data])));return Buffer.concat([size,tag,data,sum]);}
const header=Buffer.alloc(13);header.writeUInt32BE(5,0);header.writeUInt32BE(5,4);header[8]=8;header[9]=6;
const raw=Buffer.alloc(5*(1+5*4));
for(let y=0;y<5;y++)for(let x=0;x<5;x++){
 const i=y*21+1+x*4,d=Math.hypot(x+.5-2.5,y+.5-2.5);raw[i]=raw[i+1]=raw[i+2]=255;raw[i+3]=Math.round(255*Math.max(0,Math.min(1,(1.6-d)/.6)));
}
const dest=path.resolve(__dirname,'../../assets/UI/Comms/dots.png');fs.mkdirSync(path.dirname(dest),{recursive:true});
fs.writeFileSync(dest,Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]));
console.log(dest);
