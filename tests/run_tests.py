"""Run portable loader tests with a supplied Godot executable, isolated user data."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile
import struct

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from build import build

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='orckit-tests-', dir=ROOT.parent) as directory:
    runtime = Path(directory)
    (runtime / 'OrcLoader.gd').write_text(build(), encoding='utf-8')
    shutil.copy2(ROOT / 'tests' / 'regression.gd', runtime / 'regression.gd')
    with zipfile.ZipFile(runtime / 'valid.vmz', 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('mod.txt', '[mod]\nid="fixture"\n')
        archive.writestr('main.gd', 'extends Node\n')
    with zipfile.ZipFile(runtime / 'large.vmz', 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('main.gd', ' ' * (9 * 1024 * 1024))
    huge = bytearray((runtime / 'valid.vmz').read_bytes())
    central = huge.index(b'PK\x01\x02')
    struct.pack_into('<I', huge, central + 24, 33 * 1024 * 1024)
    (runtime / 'oversized.vmz').write_bytes(huge)
    name = b'battle/battle.gd\0'
    directory = struct.pack('<II', 1, len(name)) + name + struct.pack('<QQ', 0, 1) + bytes(20)
    pack = struct.pack('<4sIIIIIQQ', b'GDPC', 3, 4, 6, 4, 2, 112, 112).ljust(112, b'\0') + directory
    (runtime / 'embedded.exe').write_bytes(b'MZ' + bytes(126) + pack + struct.pack('<Q4s', len(pack), b'GDPC'))
    (runtime / 'project.godot').write_text('[application]\nconfig/name="OrcKitTests"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=800\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    env = os.environ.copy()
    env['APPDATA'] = str(runtime / 'userdata')
    env['XDG_DATA_HOME'] = str(runtime / 'userdata')
    result = subprocess.run([args.godot, '--headless', '--path', str(runtime), '--script', 'regression.gd'], env=env, timeout=90)
    sys.exit(result.returncode)
