"""Package observed PC/DX11 shader binaries using UrhoX's native cache lookup.

No generated shader names enter gameplay Lua. Missing variants still compile
normally; this is a cache for observed paths, not a claim of exhaustive coverage.
Run --check before a PC build, and restage after engine/shader changes.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/shadercache_runtime/dx11'
CACHE = ROOT / '.cli/ResCache/shadercache_runtime/dx11'
MANIFEST = ROOT / 'docs/migration/evidence/pc-shader-cache.json'
LOGS = ROOT / 'docs/migration/evidence/pc-shader-inputs'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprints():
    engine = {str(p.relative_to(ROOT)).replace('\\', '/'): digest(p) for p in [
        ROOT / '.cli/build.json', ROOT / '.cli/UrhoXRuntime.exe',
        ROOT / '.cli/shaderc.dll', ROOT / '.cli/d3dcompiler_47.dll',
        ROOT / '.cli/Autoload/Res.pak', ROOT / '.cli/Autoload/CoreData.pak',
        ROOT / '.cli/Res/shadercache_runtime/shadercache_dx11.pak']}
    shaders = {str(p.relative_to(ROOT)).replace('\\', '/'): digest(p)
               for p in sorted((ROOT / 'assets/Shaders').rglob('*'))
               if p.suffix in ('.shader', '.shaderinc')}
    return engine, shaders


def safe_entry(name):
    if not re.fullmatch(r'[A-Za-z0-9_]+_[0-9a-f]{8}\.(vs|fs|cs)', name):
        raise ValueError('Invalid cache entry: ' + name)
    return DEST / name


def check():
    data = json.loads(MANIFEST.read_text(encoding='utf-8'))
    engine, shaders = fingerprints()
    if data['engine_hashes'] != engine or data['shader_hashes'] != shaders:
        raise SystemExit('STALE: engine or shader source changed; render required paths and restage PC cache')
    for entry in data['entries']:
        path = safe_entry(entry['file'])
        if not path.is_file() or digest(path) != entry['sha256']:
            raise SystemExit('MISSING/CORRUPT: ' + str(path))
    print(json.dumps({'result': 'PASS', 'backend': 'dx11', 'files': len(data['entries']),
                      'bytes': sum(e['bytes'] for e in data['entries'])}))


def stage(log_names, excluded_programs):
    programs = set()
    logs = []
    previous = json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {'entries': []}
    excluded_programs = sorted(set(excluded_programs) | set(previous.get('excluded_programs', [])))
    LOGS.mkdir(parents=True, exist_ok=True)
    for name in log_names:
        path = (ROOT / name).resolve()
        path.relative_to(ROOT)
        text = path.read_text(encoding='utf-8-sig')
        for _, program in re.findall(r'Loaded (vertex|pixel|compute) shader ([^\r\n(]+)\(', text):
            programs.add(program.replace('/', '_'))
        # Reusing an evidence snapshot must not create another hash-prefixed copy.
        snapshot = path if path.parent == LOGS else LOGS / (digest(path)[:16] + '-' + path.name)
        if not snapshot.exists():
            shutil.copyfile(path, snapshot)
        logs.append({'file': str(snapshot.relative_to(ROOT)).replace('\\', '/'), 'sha256': digest(snapshot)})
    programs.difference_update(excluded_programs)
    if not programs:
        raise SystemExit('No successfully loaded shaders found in supplied runtime logs')
    candidates = {}
    # Retain previously staged binaries when the mutable development cache was
    # isolated for verification. Fresh runtime files take precedence.
    for folder in (DEST, CACHE):
        if not folder.exists():
            continue
        for path in folder.iterdir():
            match = re.fullmatch(r'(.+)_([0-9a-f]{8})\.(vs|fs|cs)', path.name)
            if match and match[1] in programs:
                candidates[path.name] = path
    if not candidates:
        raise SystemExit('No compiled cache files for the observed programs')
    DEST.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, src in sorted(candidates.items()):
        output = safe_entry(name)
        payload = src.read_bytes()
        signature = {'.vs': b'VSH', '.fs': b'FSH', '.cs': b'CSH'}[src.suffix]
        if len(payload) < 16 or payload[:3] != signature:
            raise SystemExit('Invalid bgfx binary: ' + name)
        if src.resolve() != output.resolve():
            shutil.copyfile(src, output)
        entries.append({'file': name, 'bytes': len(payload), 'sha256': digest(output)})
    for old in previous['entries']:
        if old['file'] not in candidates:
            path = safe_entry(old['file'])
            path.unlink(missing_ok=True)
            Path(str(path) + '.meta').unlink(missing_ok=True)
    engine, shaders = fingerprints()
    data = {'version': 1, 'backend': 'dx11', 'scope': 'Observed PC runtime programs only; native cache fallback remains enabled',
            'engine_hashes': engine, 'shader_hashes': shaders, 'logs': logs, 'entries': entries,
            'excluded_programs': excluded_programs}
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    check()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--logs', nargs='+', default=['.tmp/shader-original-out.txt', '.tmp/build-menus-out.txt', '.tmp/pc-home-out.txt'])
    parser.add_argument('--exclude-programs', nargs='*', default=[],
                        help='Previously observed program names superseded by new shader source; persisted in manifest')
    args = parser.parse_args()
    check() if args.check else stage(args.logs, args.exclude_programs)
