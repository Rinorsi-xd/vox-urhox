"""Read-only static dependency evidence; dynamic names and engine refs remain open."""
import hashlib
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
BASELINE = json.loads((ROOT / 'docs/migration/outgame-baseline.json').read_text(encoding='utf-8'))
PREPARED = json.loads((ROOT / '.tmp/outgame-prepare-cached.json').read_text(encoding='utf-8'))
if BASELINE['commit'] != PREPARED['identity']['sourceCommit']:
    raise SystemExit('Prepared package baseline differs')
manifest = json.loads(Path(PREPARED['manifest_path']).read_text(encoding='utf-8'))
packaged = {row['fs_path']: row for row in manifest['files'] if row.get('fs_path')}
files = {}
for folder in ('assets', 'scripts'):
    for path in (ROOT / folder).rglob('*'):
        if path.is_file() and not path.name.endswith('.meta'):
            name = path.relative_to(ROOT / folder).as_posix()
            if name in files:
                raise ValueError('Ambiguous resource root: ' + name)
            files[name] = path

path_pattern = re.compile(r'[A-Za-z0-9_./ -]+\.(?:lua|xml|shaderinc|shader|glsl|mdl|bin|json|png|jpg|jpeg|hdr|dds|ttf|otf|woff2|wav|ogg|mp3)\b')
quoted = re.compile(r'''["']([^"'\r\n]+)["']''')
requires = re.compile(r'''\brequire\s*\(?\s*["']([^"']+)["']''')
edges = {}
parse_errors = []


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)


for name, path in files.items():
    if path.suffix not in ('.lua', '.xml', '.json', '.shader', '.shaderinc', '.glsl'):
        continue
    text = path.read_text(encoding='utf-8-sig')
    refs = []
    try:
        if path.suffix == '.json':
            values = list(strings(json.loads(text)))
        elif path.suffix == '.xml':
            tree = ET.fromstring(text)
            values = [v for node in tree.iter() for v in node.attrib.values()]
            values.extend(node.text.strip() for node in tree.iter() if node.text and node.text.strip())
        else:
            values = quoted.findall(text)
        for value in values:
            if value in files:
                refs.append({'path': value, 'kind': 'literal'})
            # Structured resource values may be prefixed by a type, e.g. Model;Models/Box.mdl.
            for candidate in path_pattern.findall(value):
                candidate = candidate.strip()
                options = [candidate, (Path(name).parent / candidate).as_posix()]
                resolved = next((option for option in options if option in files), candidate)
                refs.append({'path': resolved, 'kind': 'literal'})
        if path.suffix == '.lua':
            for module in requires.findall(text):
                resource = module.replace('.', '/') + '.lua' if '/' not in module else module + '.lua'
                refs.append({'path': resource, 'kind': 'require'})
    except (ValueError, ET.ParseError) as error:
        parse_errors.append({'file': name, 'error': str(error)})
    edges[name] = list({(r['path'], r['kind']): r for r in refs}.values())


def closure(roots):
    pending = list(roots)
    seen = set()
    external = {}
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        for ref in edges.get(name, []):
            target = ref['path']
            if target in files:
                pending.append(target)
            else:
                record = packaged.get(target)
                key = (name, target)
                external[key] = {'from': name, **ref, 'resolution': 'PINNED_MANIFEST' if record else 'UNRESOLVED_STATIC_CANDIDATE',
                                 'source': record.get('source') if record else None}
    return seen, list(external.values())


maps = []
for identifier, scene, listing, routes in (
    ('trial', 'Scenes/TrialTrack.xml', 'Track/Resources.json', ['trial']),
    ('crater', 'Scenes/Crater.xml', 'Crater/Resources.json', ['crater', 'elimination', 'conquest', 'escort', 'story1', 'story2', 'story3', 'story4']),
    ('salvage', 'Scenes/Salvage.xml', 'Salvage/Resources.json', ['salvage']),
):
    declared = set(json.loads(files[listing].read_text(encoding='utf-8')))
    reachable, external = closure([scene, listing])
    inferred = sorted(reachable - declared - {scene, listing})
    maps.append({'id': identifier, 'routes': routes, 'scene': scene, 'downloadList': listing,
                 'declared': len(declared), 'localClosure': len(reachable), 'localOutsideDownloadList': inferred,
                 'outsideListPackageGroups': [{'file': name, 'groups': packaged.get(name, {}).get('groups', [])} for name in inferred],
                 'externalReferences': external})

reverse = {}
for name, refs in edges.items():
    for ref in refs:
        reverse.setdefault(ref['path'], set()).add(name)
assets = []
for name, path in files.items():
    if not path.is_relative_to(ROOT / 'assets'):
        continue
    body = path.read_bytes()
    assets.append({'file': name, 'sha256': hashlib.sha256(body).hexdigest(), 'bytes': len(body),
                   'packaged': name in packaged, 'staticReferrers': sorted(reverse.get(name, [])),
                   'outgoing': edges.get(name, []),
                   'referenceStatus': 'STATIC_REFERENCED' if name in reverse else 'NO_LITERAL_REF_NOT_SAFE_TO_DELETE'})
result = {'sourceCommit': BASELINE['commit'], 'manifest': Path(PREPARED['manifest_path']).name,
          'method': 'JSON and XML parsed structurally; quoted Lua/shader references and requires are static candidates. No runtime reachability or converter reproducibility claimed.',
          'limitations': ['Dynamic names, Lua long strings and constructed paths require runtime tracing.',
                         'External references absent from project manifest may be engine-internal or parser candidates; not automatically missing.',
                         'No literal ref is never proof a resource is unused. Hash/provenance parity remains a separate ledger.'],
          'parseErrors': parse_errors, 'maps': maps, 'assets': assets}
output = ROOT / 'docs/migration/evidence/full-parity' / BASELINE['commit'][:12] / 'G0/resource-closure.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'output': str(output), 'assets': len(assets), 'parseErrors': len(parse_errors),
                  'maps': [{k: m[k] for k in ('id', 'declared', 'localClosure', 'localOutsideDownloadList')} for m in maps]}, ensure_ascii=False))
