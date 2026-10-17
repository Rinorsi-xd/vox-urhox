"""Compare same-workload effects data; never treat recorder timing as performance."""
import argparse
import json
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('directory',type=Path)
p.add_argument('--before',default='eq-before-final')
p.add_argument('--candidate',default='eq-candidate-final')
p.add_argument('--timing',nargs=4,default=['timing-A1','timing-B1','timing-B2','timing-A2'])
args=p.parse_args()
def read(label):
    value=json.loads((args.directory/(label+'.json')).read_text(encoding='utf-8-sig'))
    assert value['status']=='PASS' and value['seed']==17102026
    assert [x['name']for x in value['scenarios']]==['idle','bolts','mixed']
    return value
labels=[args.before,args.candidate]+args.timing
for label in labels:
    log=(args.directory/(label+'.stderr.log')).read_text(encoding='utf-8-sig')
    errors=[line for line in log.splitlines()if 'ERROR:'in line]
    assert not errors,('INVALID_NATIVE_ERROR_LOG',label,errors[:2])
identities=[json.loads((args.directory/(label+'.identity.json')).read_text(encoding='utf-8-sig'))for label in labels]
reference=identities[0]
for value in identities:
    assert value['runtimeSha256']==reference['runtimeSha256'],'Runtime identity drift'
    assert value.get('resourcePrefix')==reference.get('resourcePrefix'),'Runtime resources drift'
    assert value.get('resourceHashes')==reference.get('resourceHashes'),'Runtime resource identity drift'
    paths=set(value['sourceHashes'])|set(reference['sourceHashes'])
    changed={key for key in paths if value['sourceHashes'].get(key)!=reference['sourceHashes'].get(key)}
    assert changed<={'scripts/render/EffectBatch.lua'},('Unexpected source drift',changed)
before_hash=identities[0]['sourceHashes']['scripts/render/EffectBatch.lua']
candidate_hash=identities[1]['sourceHashes']['scripts/render/EffectBatch.lua']
assert before_hash!=candidate_hash,'Candidate source identical to baseline'
for identity,wanted in zip(identities[2:],[before_hash,candidate_hash,candidate_hash,before_hash],strict=True):
    assert identity['sourceHashes']['scripts/render/EffectBatch.lua']==wanted,'ABBA source order mismatch'
old,new=read(args.before),read(args.candidate)
assert old['mode']==new['mode']=='equivalence'
assert old['nativeCopy']==new['nativeCopy'],'Native owned vertex attributes differ'
assert old['batchBoundaries']==new['batchBoundaries'],'Direct batch boundary cases differ'
fields=['name','frames','batches','peakBatches','groundCalls','stateDigest','geometryDigest','geometryCalls','randomTail']
equivalent=[]
for a,b in zip(old['scenarios'],new['scenarios'],strict=True):
    for key in fields:assert a[key]==b[key],(a['name'],key,a[key],b[key])
    equivalent.append({key:a[key]for key in fields})
timings=[read(label)for label in args.timing]
for value in timings:assert value['mode']=='timing'
results=[]
for i,scenario in enumerate(timings[0]['scenarios']):
    series=[value['scenarios'][i]for value in timings]
    for value in series:
        assert value['stages'] in ([],{}), 'Timing run has method wrappers'
        for key in ['name','frames','batches','peakBatches','groundCalls','randomTail']:
            assert value[key]==scenario[key],(key,value[key],scenario[key])
    baseline=(series[0]['totalMs']+series[3]['totalMs'])/(series[0]['frames']+series[3]['frames'])
    candidate=(series[1]['totalMs']+series[2]['totalMs'])/(series[1]['frames']+series[2]['frames'])
    results.append({'scenario':scenario['name'],'ABBA_totalMs':[x['totalMs']for x in series],
                    'baselineMsPerFrame':baseline,'candidateMsPerFrame':candidate,
                    'changePercent':(candidate/baseline-1)*100 if baseline else None})
report={'status':'PASS','labels':labels,'runtimeSha256':reference['runtimeSha256'],'beforeSha256':before_hash,'candidateSha256':candidate_hash,'equivalence':equivalent,'nativeCopy':old['nativeCopy'],
        'batchBoundaries':old['batchBoundaries'],'timing':results,
        'boundary':'Controlled Native Effects.Update CPU workload only. Geometry recorder verifies per-batch submission order; independent batches are combined in fixed key order because Lua pairs order differs across processes. No cross-batch order change in candidate. No full combat FPS, Web or mobile acceptance.'}
(args.directory/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':'PASS','timing':results},indent=2))
