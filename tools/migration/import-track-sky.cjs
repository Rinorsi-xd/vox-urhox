// Preserve the official sky model locally: older Web resolvers omit built-in aliases.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const cache=require('./cached-engine-sources.cjs');
const source=cache.snapshots['engine-res'];
const base='https://tapcode-sce.spark.xd.com/src/engine-res/'+source.version+'/';
const manifest=JSON.parse(cache.read(base+'manifest-'+source.client+'.json').body);
const file=manifest.files.find(file=>file.fs_path==='Models/Sphere.mdl');
if(!file)throw Error('Official sphere entry missing');
const asset=cache.read(base+'assets/'+file.uuid+'-'+file.hash+file.ext);
if(!asset||asset.body.length!==file.size||asset.body.subarray(0,4).toString()!=='UMDL')throw Error('Official sky sphere unavailable or invalid');
const root=path.resolve(__dirname,'../..');
fs.writeFileSync(path.join(root,'assets/Track/SkySphere.mdl'),asset.body);
console.log(JSON.stringify({path:'Track/SkySphere.mdl',source,file,sha256:crypto.createHash('sha256').update(asset.body).digest('hex')}));
