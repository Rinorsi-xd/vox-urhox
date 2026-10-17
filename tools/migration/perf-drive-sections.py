"""Prepare isolated current-source drive diagnostics; never starts a Runtime."""
import argparse
import hashlib
import json
import shutil
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def replace_once(source, before, after):
    assert source.count(before) == 1, before
    return source.replace(before, after)


def instrument_gait(source):
    source = "local Probe=assert(rawget(_G,'VOX_DRIVE_SCOPE'))\n" + source
    changes = [
        ('function M.Step(c,dt,ctx)\n', "function M.Step(c,dt,ctx)\n    Probe.Enter('gait.Step');Probe.Enter('gait.init')\n"),
        ('    if not ctx.supported then\n', "    if not ctx.supported then\n        Probe.Switch('gait.air')\n"),
        ('c.parked=true;Finish(c,q,p);return', "c.parked=true;Probe.Switch('gait.finish');Finish(c,q,p);Probe.Leave();Probe.Leave();return"),
        ('    local vmax=0\n', "    Probe.Switch('gait.kinematics')\n    local vmax=0\n"),
        ('    local sn=Ramp(1.5,8,vmax)', "    Probe.Switch('gait.phase')\n    local sn=Ramp(1.5,8,vmax)"),
        ("        if s.mode=='stance' then\n", "        if s.mode=='stance' then\n            Probe.Switch('gait.stance')\n"),
        ("        if s.mode=='swing' then\n", "        if s.mode=='swing' then\n            Probe.Switch('gait.swing')\n"),
        ("        if s.mode=='free' then\n", "        if s.mode=='free' then\n            Probe.Switch('gait.free')\n"),
        ("        if s.mode=='plant' then\n", "        if s.mode=='plant' then\n            Probe.Switch('gait.plant')\n"),
        ('    Finish(c,q,p)\nend', "    Probe.Switch('gait.finish');Finish(c,q,p);Probe.Leave();Probe.Leave()\nend"),
    ]
    for before, after in changes:
        source = replace_once(source, before, after)
    return source


def instrument_contact(source):
    source = "local Probe=assert(rawget(_G,'VOX_DRIVE_SCOPE'))\n" + source
    changes = [
        ('function M.Step(vehicle,cmd,dt,frame)\n', "function M.Step(vehicle,cmd,dt,frame)\n    Probe.Enter('contact.Step');Probe.Enter('contact.inputs')\n"),
        ('    local nW=math.max', "    Probe.Switch('contact.loads')\n    local nW=math.max"),
        ('    vehicle.drifting=hand', "    Probe.Switch('contact.steering')\n    vehicle.drifting=hand"),
        ('    local hi=1-.25', "    Probe.Switch('contact.wheelCommands')\n    local hi=1-.25"),
        ('    local av=body.angvel()', "    Probe.Switch('contact.handling')\n    local av=body.angvel()"),
        ('    if contact>0 then\n', "    Probe.Switch('contact.damping')\n    if contact>0 then\n"),
        ('    for _,w in ipairs(vehicle.wheels) do\n        local length=', "    Probe.Switch('contact.bottomout')\n    for _,w in ipairs(vehicle.wheels) do\n        local length="),
        ('    local support,groundDrive,groundBrake=', "    Probe.Switch('contact.telemetry')\n    local support,groundDrive,groundBrake="),
        ('    return {contact=contact', '    local result={contact=contact'),
        ('steeringAssist=steeringAssist}\nend', 'steeringAssist=steeringAssist}\n    Probe.Leave();Probe.Leave();return result\nend'),
    ]
    for before, after in changes:
        source = replace_once(source, before, after)
    return source


def prepare(destination):
    destination = destination.resolve()
    assert destination.is_relative_to(ROOT / '.tmp'), 'Probe snapshot must be inside workspace .tmp'
    assert not destination.exists(), 'Preserve existing evidence: choose a new directory'
    source_hashes = {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in (ROOT / 'scripts').rglob('*.lua')}
    shutil.copytree(ROOT / 'scripts', destination / 'scripts')
    shutil.copytree(ROOT / '.project', destination / '.project')
    if os.name == 'nt':
        subprocess.run(['cmd', '/c', 'mklink', '/J', str(destination / 'assets'), str(ROOT / 'assets')], check=True, capture_output=True)
    else:
        destination.joinpath('assets').symlink_to(ROOT / 'assets', target_is_directory=True)
    for name in ('LegGait', 'ContactControl'):
        target = destination / 'scripts/drive' / (name + '.lua')
        source = target.read_text(encoding='utf-8')
        destination.joinpath(name + '-baseline.lua').write_text(source, encoding='utf-8', newline='\n')
        transform = instrument_gait if name == 'LegGait' else instrument_contact
        destination.joinpath(name + '-sections.lua').write_text(transform(source), encoding='utf-8', newline='\n')
    probe_names = ('perf-drive-sections-native.lua', 'perf-drive-sections-scope.lua', 'perf-drive-sections-crater.lua')
    for name in probe_names:
        shutil.copyfile(HERE / name, destination / 'scripts' / name)
    variant_paths = ['LegGait-baseline.lua', 'LegGait-sections.lua', 'ContactControl-baseline.lua', 'ContactControl-sections.lua',
                     *['scripts/' + name for name in probe_names]]
    metadata = {'sourceRoot': str(ROOT), 'snapshotRoot': str(destination), 'sourceHashes': source_hashes,
                'variantHashes': {p: hashlib.sha256((destination / p).read_bytes()).hexdigest() for p in variant_paths},
                'boundary': 'Prepared only; no Native run, section timings or candidate performance result.'}
    destination.joinpath('source-identity.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    return metadata


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prepare', type=Path, required=True)
    args = parser.parse_args()
    report = prepare(args.prepare)
    print(json.dumps({'status': 'PREPARED_NOT_RUN', 'snapshotRoot': report['snapshotRoot'], 'sourceFiles': len(report['sourceHashes'])}))
