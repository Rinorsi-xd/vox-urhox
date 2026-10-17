// One actual arm, no subtraction against its unmatched baseline.
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {analyze}=require('./analyze-single-step-allocation.cjs');const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const directory=path.resolve(process.argv[2]||'.tmp/gc-ray-allocation-4a3a-1017-a/detailed');
const raw=fs.readFileSync(path.join(directory,'allocation-1.json')),idRaw=fs.readFileSync(path.join(directory,'identity.json'));
const value=JSON.parse(raw),identity=JSON.parse(idRaw);const result=analyze(value,identity);
for(const [relative,hash]of Object.entries({...identity.sourceHashes,...identity.projectHashes}))
 assert.equal(sha(fs.readFileSync(path.join(directory,relative))),hash,'Frozen input '+relative);
const get=name=>{const row=value.allocation.totals.find(item=>item.name===name);assert(row,name);return row};
const cast=get('gcRay.Cast'),cold=get('gcRay.coldBounds'),cached=get('gcRay.cachedBounds');
assert.equal(cast.calls,cold.calls+cached.calls);assert(cold.calls>0&&cached.calls>0);
const frames=value.allocation.frames.length;
const perStep=row=>({...row,inclusiveKiBPerStep:row.inclusiveKiB/frames,selfKiBPerStep:row.selfKiB/frames});
const detail={status:'SINGLE_ARM_ALLOCATION_ATTRIBUTION_PASS',pairedStatus:'FAIL_PAIRED_WORKLOAD_MISMATCH',timingValidity:'INVALID_FOR_PERFORMANCE',
 input:{raw:sha(raw),identity:sha(idRaw)},frames,measuredShots:value.measuredShots,
 parent:perStep(get('drive.TrackWorld.CastRay')),cast:perStep(cast),cold:perStep(cold),cached:perStep(cached),
 coldFractionOfCastInclusive:cold.inclusiveKiB/cast.inclusiveKiB,
 cachedFractionOfCastInclusive:cached.inclusiveKiB/cast.inclusiveKiB,
 outerCastSelfOverheadKiB:cast.inclusiveKiB-cold.inclusiveKiB-cached.inclusiveKiB,
 math:value.allocation.totals.filter(row=>row.name.startsWith('gcRay.math.')&&row.calls>0).map(perStep),
 boundary:'Only this detailed actual eight-car Native workload. Baseline trajectory is unmatched; no A/B deltas, CPU durations or speedup claims. Cold/cached rows contain complete analytic ray traversal; cold is not exclusive Bounds cost. Math inclusive values overlap nested helpers. Instrumentation itself contributes allocation. No renderer/UI/audio or device FPS acceptance.'};
const out=process.argv[3]||'docs/migration/evidence/gc-ray-allocation-next-native-1017-a-detail.json';
fs.writeFileSync(out,JSON.stringify(detail,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(detail,null,2));
