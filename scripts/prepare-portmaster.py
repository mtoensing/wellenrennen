#!/usr/bin/env python3
"""Build a local-only PortMaster-New candidate from the validated private ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BINARIES = ('WaveRace64Recomp.aarch64', 'gliden64/mupen64plus-video-GLideN64.so', 'gliden64/libwr64_m64pcore.so')


def text_hash(path):
    data = path.read_bytes()
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError(f'Not a little-endian ELF64: {path}')
    offset = struct.unpack_from('<Q', data, 40)[0]
    size, count, names = struct.unpack_from('<HHH', data, 58)
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, offset + i * size) for i in range(count)]
    table = sections[names]
    strings = data[table[4]:table[4] + table[5]]
    for section in sections:
        name = strings[section[0]:].split(b'\0', 1)[0]
        if name == b'.text':
            return hashlib.sha256(data[section[4]:section[4] + section[5]]).hexdigest()
    raise ValueError(f'No .text section: {path}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, default=ROOT / '.work/PortMaster-New/ports/wellenrennen')
    parser.add_argument('--replace', action='store_true', help='Replace only this generated port candidate')
    args = parser.parse_args()
    dest = args.destination.resolve()
    if dest.name != 'wellenrennen' or dest.parent.name != 'ports':
        parser.error('Destination must end in ports/wellenrennen')
    if dest.exists():
        roms = [p for p in dest.rglob('*') if p.suffix.lower() in ('.z64', '.n64', '.v64', '.rom')]
        if roms or not args.replace:
            parser.error('Destination exists; use --replace only after checking it. ROMs are never removed.')
        shutil.rmtree(dest)
    archive = ROOT / 'dist/wellenrennen.zip'
    if not archive.is_file():
        parser.error('Run the private ARM64 packaging workflow first')
    template = ROOT / 'portmaster/submission/wellenrennen'
    if not (template / 'screenshot.png').is_file():
        parser.error('A real 640x480 gameplay screenshot is required')
    dest.mkdir(parents=True)
    with tempfile.TemporaryDirectory(dir=ROOT / '.work') as temporary:
        with zipfile.ZipFile(archive) as package:
            for name in package.namelist():
                if '..' in Path(name).parts or name.startswith('/') or Path(name).suffix.lower() in ('.z64', '.n64', '.v64', '.rom', '.elf') or 'RecompiledFuncs/' in name:
                    raise ValueError('Unsafe archive path')
            package.extractall(temporary)
        info = json.loads((Path(temporary) / 'wellenrennen/build-info.json').read_text())
        if info.get('frontend') is not False:
            raise ValueError('Only the no-RecompFrontend build may be prepared for redistribution')
        shutil.copytree(Path(temporary) / 'wellenrennen', dest / 'wellenrennen')
    payload = dest / 'wellenrennen'
    for name in ('README.md', 'gameinfo.xml', 'port.json'):
        (payload / name).unlink(missing_ok=True)
    shutil.rmtree(payload / 'tests', ignore_errors=True)
    shutil.rmtree(payload / 'defaults', ignore_errors=True)
    shutil.rmtree(payload / 'licenses')
    (payload / 'licenses').mkdir()
    shutil.copytree(template, dest, dirs_exist_ok=True)
    (dest / 'Wellenrennen.sh').chmod(0o644)
    before = {name: text_hash(payload / name) for name in BINARIES}
    mount = ['docker', 'run', '--rm', '-v', 'wr64-work:/work', '-v', f'{ROOT}:/repo:ro', '-v', f'{payload}:/out', 'wellenrennen-build:22.04']
    subprocess.run(mount + ['python3', '/repo/scripts/collect-portmaster-licenses.py', '/out/licenses'], check=True)
    subprocess.run(mount + ['strip', '--strip-debug'] + [f'/out/{name}' for name in BINARIES], check=True)
    report = {'candidate': str(dest), 'local_only': True, 'submission_ready': False, 'binaries': {}}
    for name in BINARIES:
        path = payload / name
        after = text_hash(path)
        if after != before[name]:
            raise RuntimeError(f'Stripping changed executable instructions: {name}')
        report['binaries'][name] = {'bytes': path.stat().st_size, 'text_sha256': after}
    report['open_gates'] = ['Final reduced-asset package smoke test (device unreachable)', 'Additional CFW/device testing', 'Manual full-course/controller/exit verification', 'Contributor AI-authorship review attestation']
    (ROOT / 'dist/portmaster-preparation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    print('LOCAL PREPARATION ONLY: no fork, binary upload, or upstream PR was published.')


if __name__ == '__main__':
    main()
