"""Portable equivalent of build.sh; build.sh remains the module order source."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent

def build():
    names = re.findall(r'"\$SRC/([^"\n]+)"', (ROOT / 'build.sh').read_text())
    text = ''.join((ROOT / 'src' / name).read_text(encoding='utf-8') + '\n' for name in names)
    assert len(re.findall(r'^extends ', text, re.M)) == 1
    (ROOT / 'OrcLoader.gd').write_text(text, encoding='utf-8', newline='\n')
    return text

if __name__ == '__main__':
    build()
