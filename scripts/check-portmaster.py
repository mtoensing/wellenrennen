#!/usr/bin/env python3
"""Check only the generated port with public PortMaster tools and payload guards."""
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

port = Path(sys.argv[1]).resolve()
checkout = port.parent.parent
os.chdir(checkout)
sys.path.insert(0, str(checkout / 'tools'))
import build_release
import build_gameinfo
import build_data
import util

os.chdir(checkout)
registered = {'dirs': {}, 'scripts': {}}
env = dict(os.environ, DEVELOPER_DIR='/Library/Developer/CommandLineTools')
tree = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', 'HEAD:ports'], env=env, text=True)
for entry in tree.splitlines():
    parts = entry.split('/')
    if len(parts) > 1 and parts[0] != port.name:
        if len(parts) == 2 and parts[1].endswith('.sh'):
            registered['scripts'][parts[1]] = parts[0]
        elif len(parts) > 2:
            registered['dirs'][parts[1]] = parts[0]

assert build_release.load_port(port, {}, registered, {}) is not None
build_gameinfo.parse_gameinfo(port / 'gameinfo.xml', {})
build_data.GITHUB_RUN = True  # validation must not generate .gitignore files
large, _ = build_data.load_port(port)
assert not large, 'Raw payload must stay below the 90 MiB threshold'
for messages in util.MESSAGES.values():
    for warning in messages['warnings']:
        print('WARNING:', warning)
    assert not messages['errors'], messages['errors']

for path in port.rglob('*'):
    assert not path.is_symlink(), f'Unexpected symlink: {path}'
    if not path.is_file():
        continue
    assert path.suffix.lower() not in ('.z64', '.n64', '.v64', '.rom', '.elf'), path
    assert not {'RecompiledFuncs', 'tests', 'defaults', '__pycache__'}.intersection(path.parts), path
    assert path.stat().st_size < 90 * 1024 * 1024, path
    assert not path.name.startswith(('libSDL', 'libc.', 'libstdc++', 'libpthread', 'librt.', 'libGL.', 'libEGL', 'libGLX', 'libvulkan', 'libmali', 'libMali')), path
    if path.suffix == '.sh':
        assert b'\r' not in path.read_bytes(), 'Shell scripts must use LF'
        assert path.stat().st_mode & 0o777 == 0o644, 'Catalogue scripts must be 0644'
        subprocess.run(['bash', '-n', str(path)], check=True)
    with path.open('rb') as stream:
        head = stream.read(64)
    if head.startswith(b'\x7fELF'):
        assert head[4:6] == b'\x02\x01' and struct.unpack_from('<H', head, 18)[0] == 183, path
png = (port / 'screenshot.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack_from('>II', png, 16) == (640, 480)
metadata = json.loads((port / 'port.json').read_text())['attr']
assert metadata['arch'] == ['aarch64'] and metadata['runtime'] == []
assert metadata['reqs'] == ['analog_1', '1gb'] and metadata['min_glibc'] == '2.34'
assert json.loads((port / 'wellenrennen/build-info.json').read_text())['frontend'] is False
print('PASS: public metadata/gameinfo/size checks, catalogue layout, ROM/library guards, ARM64 ELF, LF/0644 and screenshot')
print('Not GitHub CI; additional CFW/device tests and human contributor review remain open.')
