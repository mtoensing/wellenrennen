#!/usr/bin/env python3
"""Run inside the ARM64 build container; collect the supplied native-build notices."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
repo = Path('/repo')
work = Path('/work')
cache = (work / 'build-arm64/CMakeCache.txt').read_text()
if 'WR64_WITH_FRONTEND:BOOL=OFF' not in cache:
    raise SystemExit('PortMaster packaging requires WR64_WITH_FRONTEND=OFF')
for name, relative in json.loads((repo / 'portmaster/submission/licenses.json').read_text()).items():
    shutil.copyfile(work / relative, out / f'LICENSE.{name}.txt')
for name, relative, kind in [
    ('sse2neon', 'sse2neon/sse2neon.h', 'block'),
    ('concurrentqueue', 'concurrentqueue/concurrentqueue.h', 'prefix'),
]:
    text = (work / 'wave-race-64-recomp/lib/N64ModernRuntime/thirdparty' / relative).read_text()
    if kind == 'block':
        text = text[text.index('/*'):text.index('*/') + 2] + '\n'
    else:
        text = text.split('#pragma once', 1)[0]
    (out / f'LICENSE.{name}.txt').write_text(text)
shutil.copyfile(repo / 'portmaster/submission/licenses/LICENSE.nlohmann-json.txt', out / 'LICENSE.nlohmann-json.txt')
shutil.copyfile(work / 'wave-race-64-recomp/THIRD_PARTY_NOTICES.md', out / 'NOTICE.upstream.txt')
revision = subprocess.check_output(['git', '-c', 'safe.directory=/repo', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
(out / 'SOURCE.txt').write_text(f'Complete port source, patches, pins and build scripts: https://github.com/mtoensing/wellenrennen/tree/{revision}\n')
(out / 'BUILD.txt').write_text('This build uses WR64_WITH_FRONTEND=OFF. RecompFrontend, recompui, recompinput, RmlUi and their PC UI assets are not linked or shipped. The upstream notices also describe optional components that are absent here.\n')
