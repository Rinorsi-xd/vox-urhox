"""Prepare one existing bake at half resolution; never overwrite live assets."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

from PIL import Image, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
RESOURCE = 'Crater/texture-2.png'
SIDECAR = 'Crater/texture-2.xml'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def prepare(identity_file, output):
    identity_file = identity_file.resolve()
    output = output.resolve()
    assert output.is_relative_to(ROOT / '.tmp') and not output.exists(), 'Use a fresh project .tmp directory'
    identity_bytes = identity_file.read_bytes()
    identity = json.loads(identity_bytes)
    assert identity['ok']
    dist = Path(identity['source_directory']) / 'dist'
    manifest_file = Path(identity['manifest_path'])
    manifest_bytes = manifest_file.read_bytes()
    manifest = json.loads(manifest_bytes)
    assert manifest['assets_pak'] == 0, 'Loose frozen payloads required'
    row = next(item for item in manifest['files'] if item['fs_path'] == RESOURCE)
    sidecar = next(item for item in manifest['files'] if item['fs_path'] == SIDECAR)

    def payload(item):
        return dist / 'assets' / (item['uuid'] + '-' + item['hash'] + item['ext'])

    source_file = payload(row)
    source = source_file.read_bytes()
    assert len(source) == row['size'] and f'{zlib.crc32(source):08x}' == row['hash']
    assert source[:8] == b'\x89PNG\r\n\x1a\n'
    sidecar_bytes = payload(sidecar).read_bytes()
    assert b'<mipmap enable="false"' in sidecar_bytes and b'mode="bilinear"' in sidecar_bytes
    assert sha(source) == sha((ROOT / 'assets' / RESOURCE).read_bytes()), 'Live/source provenance drift'
    with Image.open(source_file) as image:
        image.load()
        assert image.size == (4096, 4096) and image.mode == 'RGBA'
        source_extrema = image.getextrema()
        # Bake RG are linear scalar data, not sRGB color. Exact 2x2 area sampling.
        resized = image.resize((2048, 2048), Image.Resampling.BOX)
        target_extrema = resized.getextrema()
        output.mkdir(parents=True)
        target = output / 'texture-2.png'
        resized.save(target, format='PNG', optimize=False, compress_level=6)
        reference_pixels = resized.tobytes()
    candidate = target.read_bytes()
    assert struct.unpack('>II', candidate[16:24]) == (2048, 2048)
    assert candidate[24:26] == b'\x08\x06', '8-bit RGBA required'
    with Image.open(target) as loaded:
        loaded.load()
        assert loaded.mode == 'RGBA' and loaded.tobytes() == reference_pixels
        assert not loaded.info, 'No gamma/profile/metadata injected'
    assert source == source_file.read_bytes(), 'Frozen resource changed'
    record = {
        'status': 'PREPARED_NOT_RUN',
        'sourceIdentity': str(identity_file), 'sourceIdentitySha256': sha(identity_bytes),
        'sourceManifest': str(manifest_file), 'sourceManifestSha256': sha(manifest_bytes),
        'resource': RESOURCE, 'resourceEntry': row,
        'source': {'path': str(source_file), 'sha256': sha(source), 'bytes': len(source),
                   'width': 4096, 'height': 4096, 'mode': 'RGBA', 'extrema': source_extrema},
        'candidate': {'path': str(target), 'sha256': sha(candidate), 'crc32': f'{zlib.crc32(candidate):08x}',
                      'bytes': len(candidate), 'width': 2048, 'height': 2048,
                      'mode': 'RGBA', 'extrema': target_extrema},
        'sidecar': {'resource': SIDECAR, 'sha256': sha(sidecar_bytes), 'unchanged': True},
        'resample': {'algorithm': 'Pillow BOX', 'pillow': pillow_version,
                     'linearData': True, 'gammaConversion': False, 'quantization': False,
                     'sourcePixels': 4096 * 4096, 'candidatePixels': 2048 * 2048},
        'checks': ['frozen manifest CRC/size', 'live/source SHA identity', '4096 RGBA input',
                   'single mip bilinear sidecar', '2048 RGBA output', 'saved pixel roundtrip',
                   'no added metadata', 'frozen source untouched'],
        'theoreticalUncompressedSingleMipBytes': {'beforeRGBA': 67108864, 'afterRGBA': 16777216,
                                                 'savedRGBA': 50331648},
        'boundary': 'Existing scalar bake resampling only; no live assets, materials, UV, physics, scripts, or source freeze changed. No build, Runtime, visual acceptance, GPU allocation or performance claim.',
    }
    (output / 'candidate.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    return record


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--identity', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.identity, args.out)))
