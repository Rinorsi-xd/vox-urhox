"""Check the actual Maker manifest, not just source-tree module existence."""
import argparse
import fnmatch
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("manifest", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
files = {f.get("fs_path"): f for f in manifest["files"]}
expected = sorted(p.relative_to(root / "scripts").as_posix()
                  for p in (root / "scripts").rglob("*.lua"))
missing = [name for name in expected if name not in files]
not_blocking = [name for name in expected if name in files
                and "#blocking" not in files[name].get("groups", [])]
assert not missing, f"Scripts omitted from Maker package: {missing}"
assert not not_blocking, f"Startup script downloads not blocking: {not_blocking}"
assert "construction/Blueprint.lua" in files, "Construction entry is missing"
assert not (root / "scripts/build").exists(), "Maker excludes directories named build"
print(f"PASS: {len(expected)} Lua scripts present and blocking in {args.manifest.name}")

# Synchronous shader compilation cannot wait for nonblocking .shaderinc files.
# Check emitted payloads too: source-tree existence hid the original Web failure.
assert "boot" in manifest["preload_groups"], "Boot group is not preloaded"
boot_rules = json.loads((root / '.project/resources.json').read_text('utf8'))['groups']['boot']
def startup_expected(name):
    included = any(fnmatch.fnmatchcase(name, rule) for rule in boot_rules if not rule.startswith('!'))
    excluded = any(fnmatch.fnmatchcase(name, rule[1:]) for rule in boot_rules if rule.startswith('!'))
    return included and not excluded
startup = [f for name, f in files.items() if name and (root / "assets" / name).is_file() and
           startup_expected(name)]
assert any(f["fs_path"].endswith("PlanarClip.shaderinc") for f in startup)
assert any(f["fs_path"].endswith("VoxHemi.shaderinc") for f in startup)
for f in startup:
    assert "boot" in f.get("groups", []), f"Startup dependency not preloaded: {f['fs_path']}"
    payload = args.manifest.parent.parent / "assets" / f"{f['uuid']}-{f['hash']}{f['ext']}"
    assert payload.is_file(), f"Missing emitted payload: {f['fs_path']}"
    assert payload.stat().st_size == f["size"], f"Wrong payload size: {f['fs_path']}"
assert not any("boot" in f.get("groups", []) for name, f in files.items()
               if name and name.startswith("Crater/")), "Crater must remain on demand"
print(f"PASS: {len(startup)} startup assets preloaded with complete payloads; Crater stays on demand")

lut = files['Rendering/RectLightLUT.bin']
payload = args.manifest.parent.parent / 'assets' / f"{lut['uuid']}-{lut['hash']}{lut['ext']}"
original = (root / 'assets/Rendering/RectLightLUT.bin').read_bytes()
assert payload.read_bytes() == original and original[:4] == b'DDS ', 'LTC data was cooked'
import struct
assert struct.unpack_from('<I', original, 84)[0] == 113, 'LTC must retain signed RGBA16F'
assert len(original) == 128 + 64 * 128 * 8
print('PASS: rectangle-light lookup remains byte-identical RGBA16F in Web package')

# Cold map entry must download the textures before XML background loading.
# Texture settings sidecars stay in the package but are not standalone media.
import xml.etree.ElementTree as ET
for folder in ("Track", "Crater"):
    names = json.loads((root / "assets" / folder / "Resources.json").read_text("utf8"))
    assert len(names) == len(set(names)), f"Duplicate {folder} downloads"
    for name in names:
        assert name in files, f"Unresolvable {folder} download: {name}"
        assert not name.endswith(".ktx"), f"Unsupported Web RG8 bake: {name}"
        if name.endswith(".xml"):
            assert not (root / "assets" / name).with_suffix(".png").exists(), name
    for material in (root / "assets" / folder).glob("material-*.xml"):
        for texture in ET.parse(material).getroot().findall("surfacetexture"):
            name = texture.get("texture")
            assert name in names, f"Cold map texture missing from gate: {name}"
    assert not any("boot" in files[n].get("groups", []) for n in names
                   if n.startswith(folder + "/")), f"{folder} is not on demand"
    print(f"PASS: {folder} cold-entry dependencies resolve ({len(names)} resources)")

# CPU Image and Texture2DArray readers cannot decode the remote cooker's ASTC
# KTX payloads. These are PNG bytes deliberately shipped as non-image resources.
cpu_images = [f'Crater/{kind}-{i}.bin' for kind in ('albedo', 'nra') for i in range(6)]
cpu_images.append('Crater/texture-0.bin')
downloads = json.loads((root / 'assets/Crater/Resources.json').read_text('utf8'))
for name in cpu_images:
    f = files[name]
    assert f['ext'] == '.bin' and not any(k.startswith('hash@') for k in f), name
    assert name in downloads and 'boot' not in f.get('groups', []), name
    data = (root / 'assets' / name).read_bytes()
    payload = args.manifest.parent.parent / 'assets' / f"{f['uuid']}-{f['hash']}{f['ext']}"
    assert data.startswith(b'\x89PNG\r\n\x1a\n') and payload.read_bytes() == data, name
for kind in ('albedo', 'nra'):
    layers = ET.parse(root / f'assets/Crater/{kind}.xml').getroot().findall('layer')
    assert [layer.get('name') for layer in layers] == [f'Crater/{kind}-{i}.bin' for i in range(6)]
    for i in range(6):
        original = f'Crater/{kind}-{i}.png'
        assert original not in downloads and original not in files, f'Offline terrain source redundantly shipped: {original}'
        assert f'Crater/{kind}-{i}.xml' not in files, 'Offline PNG settings sidecar redundantly shipped'
print('PASS: 13 CPU images retain exact PNG payloads outside GPU texture cooking')
print('PASS: 12 offline terrain PNG originals and their settings are excluded from downloads and package')
